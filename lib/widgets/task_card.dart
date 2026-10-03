import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../models/task.dart';
import '../dialogs/task_edit_dialog.dart';
import '../dialogs/warning_dialog.dart';
import 'obsidian_markdown_view.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final ScheduleController controller;
  final int depth;
  final VoidCallback onInspectInGraph;

  const TaskCard({
    super.key,
    required this.task,
    required this.controller,
    this.depth = 0,
    required this.onInspectInGraph,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _subtasksExpanded = true;

  Future<void> _handleCompletionToggle(bool? value) async {
    if (value == null) return;
    final task = widget.task;

    if (value == true) {
      // Check for incomplete prerequisites and subtasks
      final incomplete = widget.controller.schedule.getIncompletePrerequisitesAndSubtasks(task);
      if (incomplete.isNotEmpty) {
        final proceed = await WarningDialog.show(
          context: context,
          title: 'Mark Task Complete',
          warnings: incomplete
              .map((t) => "Task '${t.name}' (ID: ${t.taskId}) is still incomplete.")
              .toList(),
          proceedLabel: 'Mark All Complete',
          proceedColor: Colors.teal,
          icon: Icons.check_circle_outline,
        );

        if (proceed) {
          await widget.controller.setTaskCompletion(task, true, cascade: true);
        }
        return;
      }
      await widget.controller.setTaskCompletion(task, true, cascade: false);
    } else {
      await widget.controller.setTaskCompletion(task, false);
    }
  }

  Future<void> _handleDelete() async {
    final task = widget.task;
    final blocked = widget.controller.schedule.getTasksBlockedBy(task);

    if (blocked.isNotEmpty) {
      final proceed = await WarningDialog.show(
        context: context,
        title: 'Delete Dependent Task',
        warnings: blocked
            .map((t) =>
                "Task '${t.name}' depends on this task as a requisite. Deleting will remove it as a dependency.")
            .toList(),
        proceedLabel: 'Delete Anyway',
        proceedColor: Theme.of(context).colorScheme.error,
        icon: Icons.delete_forever,
      );
      if (!proceed) return;
    }

    await widget.controller.deleteTask(task.taskId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = widget.controller.schedule;
    final task = widget.task;

    final isOverdue = schedule.isTaskOverdue(task);
    final effectivePriority = schedule.getEffectivePriority(task);
    final effectiveDeadline = schedule.getEffectiveDeadline(task);

    // Milestone lookup
    final milestone = task.milestone != null
        ? schedule.milestones.cast().firstWhere(
              (m) => m.milestoneId == task.milestone,
              orElse: () => null,
            )
        : null;

    // Teammates lookup
    final assignees = task.assignees
        .map((id) => schedule.teammates.cast().firstWhere(
              (p) => p.personId == id,
              orElse: () => null,
            ))
        .whereType<dynamic>()
        .toList();

    // Requisite tasks lookup
    final requisiteTasks = task.dependencies
        .map((id) => schedule.findTaskById(id))
        .whereType<Task>()
        .toList();

    final hasSubtasks = task.subtasks.isNotEmpty;

    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 500;

    return Padding(
      padding: EdgeInsets.only(
        left: widget.depth * (isNarrow ? 12.0 : 20.0),
        top: 4,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: widget.depth == 0 ? 1.5 : 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isOverdue
                    ? theme.colorScheme.error
                    : task.completed
                        ? Colors.green.withValues(alpha: 0.5)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: isOverdue ? 2 : 1,
              ),
            ),
            color: task.completed
                ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6)
                : isOverdue
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.08)
                    : theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Checkbox, Title, Badges, Actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Subtask expand toggle if has subtasks
                      if (hasSubtasks)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _subtasksExpanded ? Icons.expand_more : Icons.chevron_right,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _subtasksExpanded = !_subtasksExpanded;
                            });
                          },
                        )
                      else if (widget.depth > 0)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                        ),

                      // Checkbox
                      Checkbox(
                        value: task.completed,
                        activeColor: Colors.green,
                        onChanged: _handleCompletionToggle,
                      ),

                      // Task Name
                      Expanded(
                        child: Text(
                          task.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: task.completed ? TextDecoration.lineThrough : null,
                            color: task.completed ? theme.colorScheme.outline : null,
                          ),
                        ),
                      ),

                      // Priority Chip
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                isNarrow ? 'OVERDUE' : 'OVERDUE (Highest Priority)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (effectivePriority > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'P$effectivePriority',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      const SizedBox(width: 6),

                      // Actions menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        tooltip: 'Task Actions',
                        onSelected: (val) {
                          switch (val) {
                            case 'add_subtask':
                              TaskEditDialog.show(
                                context: context,
                                controller: widget.controller,
                                parentTaskId: task.taskId,
                              );
                              break;
                            case 'edit':
                              TaskEditDialog.show(
                                context: context,
                                controller: widget.controller,
                                taskToEdit: task,
                              );
                              break;
                            case 'inspect':
                              widget.controller.selectTask(task);
                              widget.onInspectInGraph();
                              break;
                            case 'duplicate':
                              TaskEditDialog.show(
                                context: context,
                                controller: widget.controller,
                                templateTask: task,
                              );
                              break;
                            case 'delete':
                              _handleDelete();
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'add_subtask',
                            child: Row(
                              children: [
                                Icon(Icons.add_task, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('Add Subtask')),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(Icons.copy_all, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('Duplicate Task')),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('Edit Details')),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'inspect',
                            child: Row(
                              children: [
                                Icon(Icons.account_tree_outlined, size: 18),
                                SizedBox(width: 8),
                                Expanded(child: Text('Inspect in Graph View')),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18, color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Delete Task',
                                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Row 2: Metadata tags (Deadline, Milestone, Workload, Assignees)
                  Padding(
                    padding: EdgeInsets.only(left: isNarrow ? 8 : 36, top: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Deadline
                        if (effectiveDeadline != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event_outlined,
                                  size: 13,
                                  color: isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    task.deadline != null
                                        ? effectiveDeadline.formatted
                                        : 'Inferred: ${effectiveDeadline.formatted}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: isOverdue ? theme.colorScheme.error : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Milestone
                        if (milestone != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flag, size: 12, color: theme.colorScheme.tertiary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    milestone.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onTertiaryContainer,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Workload
                        if (task.workload != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${task.workload}h',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                        // Assignee chips
                        ...assignees.map((person) => Tooltip(
                              message: 'Assigned to ${person.name}',
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(
                                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )),

                        // Requisite Dependencies Tag
                        if (requisiteTasks.isNotEmpty)
                          Tooltip(
                            message:
                                'Needs: ${requisiteTasks.map((t) => t.name).join(", ")}',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${requisiteTasks.length} ${requisiteTasks.length == 1 ? "dep" : "deps"}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Row 3: Markdown Note (First line visible by default, expandable)
                  if (task.note != null && task.note!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 6),
                      child: ObsidianMarkdownView(note: task.note),
                    ),
                ],
              ),
            ),
          ),

          // Nested Subtasks
          if (hasSubtasks && _subtasksExpanded)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: task.subtasks
                  .map(
                    (sub) => TaskCard(
                      task: sub,
                      controller: widget.controller,
                      depth: widget.depth + 1,
                      onInspectInGraph: widget.onInspectInGraph,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
