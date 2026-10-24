import 'package:flutter/material.dart';

import '../controllers/schedule_controller.dart';
import '../dialogs/task_edit_dialog.dart';
import '../models/task.dart';
import '../widgets/searchable_menu.dart';
import '../widgets/task_card.dart';

class TaskListView extends StatefulWidget {
  final ScheduleController controller;
  final VoidCallback onNavigateToGraph;

  const TaskListView({
    super.key,
    required this.controller,
    required this.onNavigateToGraph,
  });

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  String _searchQuery = '';
  int? _filterMilestone;
  int? _filterPerson;
  bool _onlyIncomplete = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = widget.controller.schedule;
    final milestones = schedule.milestones;

    // Drop stale selections when a teammate is deleted or a schedule imported.
    if (_filterPerson != null &&
        !schedule.teammates.any((person) => person.personId == _filterPerson)) {
      _filterPerson = null;
    }
    final visibleTaskIds = <int>{};
    final query = _searchQuery.toLowerCase();
    bool includeTask(Task task) {
      // Visit every descendant, retaining ancestors of matching tasks.
      var hasMatchingChild = false;
      for (final child in task.subtasks) {
        if (includeTask(child)) hasMatchingChild = true;
      }
      final matches =
          (!_onlyIncomplete || !task.completed) &&
          (_filterMilestone == null || task.milestone == _filterMilestone) &&
          (_filterPerson == null || task.assignees.contains(_filterPerson)) &&
          (query.isEmpty ||
              task.name.toLowerCase().contains(query) ||
              (task.note?.toLowerCase().contains(query) ?? false));
      if (matches || hasMatchingChild) {
        visibleTaskIds.add(task.taskId);
        return true;
      }
      return false;
    }

    final tasks = schedule.tasks.where(includeTask).toList();

    return Column(
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final dropdownWidth = width < 600 ? (width - 12) / 2 : 220.0;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: width >= 900 ? width - 646 : width,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tasks or notes...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
                    ),
                  ),
                  SizedBox(
                    width: dropdownWidth,
                    child: SearchableDropdown<int?>(
                      labelText: 'Milestone',
                      isDense: true,
                      value: _filterMilestone,
                      items: [
                        const SearchableItem<int?>(
                          value: null,
                          label: 'All Milestones',
                          isNoneOption: true,
                        ),
                        ...milestones.map(
                          (m) => SearchableItem<int?>(
                            value: m.milestoneId,
                            label: m.name,
                            subtitle:
                                'ID: ${m.milestoneId}${m.deadline != null ? ' • Due: ${m.deadline!.formatted}' : ''}',
                            leading: const Icon(
                              Icons.flag,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _filterMilestone = value),
                    ),
                  ),
                  SizedBox(
                    width: dropdownWidth,
                    // A non-null sentinel distinguishes All People from cancelling
                    // the searchable menu, so dismissing it preserves the filter.
                    child: SearchableDropdown<String>(
                      key: const Key('taskPersonFilter'),
                      labelText: 'Assigned person',
                      isDense: true,
                      value: _filterPerson?.toString() ?? 'all',
                      items: [
                        const SearchableItem(
                          value: 'all',
                          label: 'All People',
                          isNoneOption: true,
                        ),
                        ...schedule.teammates.map(
                          (person) => SearchableItem(
                            value: person.personId.toString(),
                            label: person.name,
                            subtitle: 'ID: ${person.personId}',
                            leading: const Icon(Icons.person_outline, size: 16),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _filterPerson = int.tryParse(value)),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Incomplete Only'),
                    selected: _onlyIncomplete,
                    onSelected: (value) =>
                        setState(() => _onlyIncomplete = value),
                  ),
                ],
              );
            },
          ),
        ),

        // Task Tree List
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.checklist_rtl,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tasks match the filter.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Task'),
                        onPressed: () {
                          TaskEditDialog.show(
                            context: context,
                            controller: widget.controller,
                          );
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskCard(
                      key: ValueKey(task.taskId),
                      task: task,
                      controller: widget.controller,
                      depth: 0,
                      visibleTaskIds: visibleTaskIds,
                      onInspectInGraph: widget.onNavigateToGraph,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
