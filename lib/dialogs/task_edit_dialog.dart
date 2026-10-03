import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/schedule_controller.dart';
import '../models/task.dart';
import '../models/schedule_date.dart';
import '../widgets/obsidian_markdown_view.dart';
import '../widgets/searchable_menu.dart';
import 'date_picker_dialog.dart';
import 'warning_dialog.dart';

class TaskEditDialog extends StatefulWidget {
  final ScheduleController controller;
  final Task? taskToEdit;
  final int? parentTaskId; // If creating a subtask
  final Task? templateTask; // Explicit task to duplicate values from

  const TaskEditDialog({
    super.key,
    required this.controller,
    this.taskToEdit,
    this.parentTaskId,
    this.templateTask,
  });

  static Future<void> show({
    required BuildContext context,
    required ScheduleController controller,
    Task? taskToEdit,
    int? parentTaskId,
    Task? templateTask,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TaskEditDialog(
        controller: controller,
        taskToEdit: taskToEdit,
        parentTaskId: parentTaskId,
        templateTask: templateTask,
      ),
    );
  }

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _workloadController;
  late final TextEditingController _priorityController;
  late final TextEditingController _noteController;

  ScheduleDate? _deadline;
  int? _selectedMilestone;
  late Set<int> _selectedAssignees;
  late Set<int> _selectedDependencies;
  bool _completed = false;
  Task? _selectedTemplateTask;

  late TabController _noteTabController;

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;

    if (task != null) {
      _nameController = TextEditingController(text: task.name);
      _workloadController = TextEditingController(
        text: task.workload != null ? task.workload.toString() : '',
      );
      _priorityController = TextEditingController(
        text: task.priority != null ? task.priority.toString() : '',
      );
      _noteController = TextEditingController(text: task.note ?? '');

      _deadline = task.deadline;
      _selectedMilestone = task.milestone;
      _selectedAssignees = Set.from(task.assignees);
      _selectedDependencies = Set.from(task.dependencies);
      _completed = task.completed;
      _selectedTemplateTask = null;
    } else {
      // User story: Default values from most recently added task or explicit template task
      final template = widget.templateTask ?? widget.controller.mostRecentlyAddedTask;
      _selectedTemplateTask = template;

      _nameController = TextEditingController(
        text: template != null ? '${template.name} (Copy)' : '',
      );
      _workloadController = TextEditingController(
        text: template?.workload != null ? template!.workload.toString() : '',
      );
      _priorityController = TextEditingController(
        text: template?.priority != null ? template!.priority.toString() : '',
      );
      _noteController = TextEditingController(text: template?.note ?? '');

      _deadline = template?.deadline;
      _selectedMilestone = template?.milestone;
      _selectedAssignees = template != null ? Set.from(template.assignees) : {};
      _selectedDependencies = template != null ? Set.from(template.dependencies) : {};
      _completed = false;

      // If adding subtask and milestone is null, default from parent
      if (widget.parentTaskId != null) {
        final parent = widget.controller.schedule.findTaskById(widget.parentTaskId!);
        if (parent != null) {
          _selectedMilestone ??= parent.milestone;
          if (_selectedAssignees.isEmpty) {
            _selectedAssignees.addAll(parent.assignees);
          }
        }
      }
    }

    _noteTabController = TabController(length: 2, vsync: this);
  }

  void _applyTemplate(Task? template) {
    setState(() {
      _selectedTemplateTask = template;
      if (template != null) {
        _nameController.text = '${template.name} (Copy)';
        _workloadController.text = template.workload != null ? template.workload.toString() : '';
        _priorityController.text = template.priority != null ? template.priority.toString() : '';
        _noteController.text = template.note ?? '';
        _deadline = template.deadline;
        _selectedMilestone = template.milestone;
        _selectedAssignees = Set.from(template.assignees);
        _selectedDependencies = Set.from(template.dependencies);
      } else {
        _nameController.clear();
        _workloadController.clear();
        _priorityController.clear();
        _noteController.clear();
        _deadline = null;
        _selectedMilestone = null;
        _selectedAssignees.clear();
        _selectedDependencies.clear();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _workloadController.dispose();
    _priorityController.dispose();
    _noteController.dispose();
    _noteTabController.dispose();
    super.dispose();
  }

  /// Exclude self and all subtask descendants to prevent cycles in dependencies
  List<Task> _getEligibleDependencyCandidates() {
    final all = widget.controller.schedule.getAllTasks();
    if (widget.taskToEdit == null) {
      return all;
    }
    final selfAndDescendantIds = widget.controller.schedule
        .getAllSubtasksRecursively(widget.taskToEdit!)
        .map((s) => s.taskId)
        .toSet();
    selfAndDescendantIds.add(widget.taskToEdit!.taskId);

    return all.where((t) => !selfAndDescendantIds.contains(t.taskId)).toList();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task name is required.')),
      );
      return;
    }

    final workload = int.tryParse(_workloadController.text.trim());
    final priority = int.tryParse(_priorityController.text.trim());
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text;

    // User story 10: Check deadline warnings
    if (_deadline != null) {
      final dummyTask = widget.taskToEdit ??
          Task(
            taskId: widget.controller.schedule.nextTaskId,
            name: name,
            milestone: _selectedMilestone,
            dependencies: _selectedDependencies.toList(),
          );

      // Temporarily assign milestone and dependencies to test warnings
      final testTask = dummyTask.copyWith(
        name: name,
        milestone: _selectedMilestone,
        dependencies: _selectedDependencies.toList(),
      );

      final warnings = widget.controller.schedule.checkDeadlineWarnings(testTask, _deadline!);
      if (warnings.isNotEmpty) {
        final proceed = await WarningDialog.show(
          context: context,
          title: 'Deadline Conflict Warning',
          warnings: warnings,
          proceedLabel: 'Set Deadline Anyway',
          proceedColor: Colors.amber.shade800,
        );
        if (!proceed) return;
      }
    }

    if (widget.taskToEdit == null) {
      // Add new task
      if (widget.parentTaskId != null) {
        // Add subtask (User story 3)
        await widget.controller.addSubtask(
          parentTaskId: widget.parentTaskId!,
          name: name,
          workload: workload,
          deadline: _deadline,
          dependencies: _selectedDependencies.toList(),
          assignees: _selectedAssignees.toList(),
          milestone: _selectedMilestone,
          priority: priority,
          note: note,
        );
      } else {
        // Add top-level task (User story 1)
        await widget.controller.addTopLevelTask(
          name: name,
          workload: workload,
          deadline: _deadline,
          dependencies: _selectedDependencies.toList(),
          assignees: _selectedAssignees.toList(),
          milestone: _selectedMilestone,
          priority: priority,
          note: note,
        );
      }
    } else {
      // Update existing task
      final updated = widget.taskToEdit!.copyWith(
        name: name,
        workload: workload,
        clearWorkload: workload == null,
        deadline: _deadline,
        clearDeadline: _deadline == null,
        milestone: _selectedMilestone,
        clearMilestone: _selectedMilestone == null,
        priority: priority,
        clearPriority: priority == null,
        dependencies: _selectedDependencies.toList(),
        assignees: _selectedAssignees.toList(),
        completed: _completed,
        note: note,
        clearNote: note == null,
      );
      await widget.controller.updateTask(updated);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.taskToEdit != null;
    final isSubtask = widget.parentTaskId != null ||
        (isEditing && widget.controller.schedule.findParentTask(widget.taskToEdit!.taskId) != null);

    final teammates = widget.controller.schedule.teammates;
    final milestones = widget.controller.schedule.milestones;
    final dependencyCandidates = _getEligibleDependencyCandidates();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSubtask ? Icons.subdirectory_arrow_right : Icons.assignment_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing
                            ? 'Edit ${isSubtask ? "Subtask" : "Task"}'
                            : 'Add ${isSubtask ? "Subtask" : "Task"}',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User story: Duplicate values from other tasks
                      if (!isEditing) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.copy_all, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Duplicate values from task:',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_selectedTemplateTask != null)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onPressed: () => _applyTemplate(null),
                                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SearchableDropdown<Task?>(
                                labelText: 'Template Task',
                                hintText: 'Select task to duplicate values...',
                                value: _selectedTemplateTask,
                                items: [
                                  const SearchableItem<Task?>(
                                    value: null,
                                    label: 'None (Blank Task)',
                                    isNoneOption: true,
                                  ),
                                  ...widget.controller.schedule.getAllTasks().map((t) {
                                    return SearchableItem<Task?>(
                                      value: t,
                                      label: '#${t.taskId} ${t.name}',
                                      subtitle: 'Workload: ${t.workload ?? '-'}h • Priority: ${t.priority ?? '-'}',
                                      leading: Icon(
                                        t.completed ? Icons.check_circle : Icons.task_alt,
                                        color: theme.colorScheme.primary,
                                        size: 16,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (picked) {
                                  _applyTemplate(picked);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Task Name
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Task Name *',
                          hintText: 'e.g. Implement authentication endpoints',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: !isEditing,
                      ),
                      const SizedBox(height: 16),

                      // Workload and Priority row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _workloadController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Workload (man-hours)',
                                hintText: 'e.g. 10',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer_outlined, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _priorityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Priority (higher = urgent)',
                                hintText: 'e.g. 1, 2, 3',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.priority_high, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Deadline selector with granularity
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.event,
                          color: _deadline != null ? theme.colorScheme.primary : null,
                        ),
                        title: Text(
                          _deadline != null
                              ? 'Deadline: ${_deadline!.formatted}'
                              : 'No Explicit Deadline',
                          style: TextStyle(
                            fontWeight: _deadline != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          _deadline != null
                              ? 'Instant: ${_deadline!.endInstant.toLocal().toString().replaceAll('.000', '')}'
                              : 'Will infer minimum of dependent tasks and milestone',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_deadline != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: 'Clear Deadline',
                                onPressed: () {
                                  setState(() => _deadline = null);
                                },
                              ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month, size: 16),
                              label: Text(_deadline == null ? 'Set Deadline' : 'Change'),
                              onPressed: () async {
                                final picked = await ScheduleDatePickerDialog.show(
                                  context,
                                  initialDate: _deadline,
                                );
                                if (picked != null) {
                                  setState(() => _deadline = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 24),

                      // Milestone selector (User story 8 & 20: Search by name in menu)
                      SearchableDropdown<int?>(
                        labelText: 'Assigned Milestone',
                        prefixIcon: Icons.flag_outlined,
                        value: _selectedMilestone,
                        helperText:
                            'Assigning a milestone will recursively assign it to subtasks and requisite tasks without a milestone.',
                        items: [
                          const SearchableItem<int?>(
                            value: null,
                            label: 'None (Unassigned)',
                            isNoneOption: true,
                          ),
                          ...milestones.map((m) => SearchableItem<int?>(
                                value: m.milestoneId,
                                label: '${m.name} (ID: ${m.milestoneId})',
                                subtitle: m.deadline != null ? 'Due: ${m.deadline!.formatted}' : null,
                                leading: const Icon(Icons.flag, size: 18, color: Colors.blue),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedMilestone = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Teammate Assignees (User story 6 & 20: Search by name in menu)
                      SearchableMultiSelectMenu<int>(
                        title: 'Assigned Teammates',
                        prefixIcon: Icons.people_outline,
                        hintText: teammates.isEmpty
                            ? 'No teammates available'
                            : 'Click to search and assign teammates...',
                        selectedValues: _selectedAssignees,
                        items: teammates
                            .map((person) => SearchableItem<int>(
                                  value: person.personId,
                                  label: person.name,
                                  subtitle: 'Teammate ID: ${person.personId}',
                                  leading: CircleAvatar(
                                    radius: 12,
                                    child: Text(person.name.isNotEmpty
                                        ? person.name[0].toUpperCase()
                                        : '?'),
                                  ),
                                ))
                            .toList(),
                        onChanged: (newIds) {
                          setState(() {
                            _selectedAssignees.clear();
                            _selectedAssignees.addAll(newIds);
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Dependencies (User story 2 & 20: Search requisite tasks by name in menu)
                      SearchableMultiSelectMenu<int>(
                        title: 'Requisite Dependencies',
                        prefixIcon: Icons.account_tree_outlined,
                        hintText: dependencyCandidates.isEmpty
                            ? 'No other tasks available'
                            : 'Click to search and select requisite tasks...',
                        selectedValues: _selectedDependencies,
                        items: dependencyCandidates
                            .map((cand) => SearchableItem<int>(
                                  value: cand.taskId,
                                  label: '#${cand.taskId} ${cand.name}',
                                  subtitle: cand.deadline != null
                                      ? 'Due: ${cand.deadline!.formatted}'
                                      : null,
                                  leading: const Icon(Icons.task_alt, size: 18, color: Colors.indigo),
                                ))
                            .toList(),
                        onChanged: (newIds) {
                          setState(() {
                            _selectedDependencies.clear();
                            _selectedDependencies.addAll(newIds);
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Obsidian Markdown Note (User story 4)
                      Text(
                        'Task Note (Obsidian-flavoured Markdown)',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            TabBar(
                              controller: _noteTabController,
                              tabs: const [
                                Tab(text: 'Edit Markdown', icon: Icon(Icons.edit_note, size: 18)),
                                Tab(text: 'Preview', icon: Icon(Icons.visibility_outlined, size: 18)),
                              ],
                            ),
                            SizedBox(
                              height: 150,
                              child: TabBarView(
                                controller: _noteTabController,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextField(
                                      controller: _noteController,
                                      maxLines: null,
                                      expands: true,
                                      decoration: const InputDecoration(
                                        hintText: '# Note Title\nWrite obsidian-flavoured markdown here...',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SingleChildScrollView(
                                      child: ValueListenableBuilder<TextEditingValue>(
                                        valueListenable: _noteController,
                                        builder: (ctx, val, _) => ObsidianMarkdownView(
                                          note: val.text,
                                          initialExpanded: true,
                                          allowToggle: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Create Task'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
