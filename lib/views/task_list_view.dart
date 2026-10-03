import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../dialogs/task_edit_dialog.dart';
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
  bool _onlyIncomplete = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = widget.controller.schedule;
    final milestones = schedule.milestones;

    // Filter top-level tasks based on search/milestone/status
    final tasks = schedule.tasks.where((task) {
      if (_onlyIncomplete && task.completed) return false;
      if (_filterMilestone != null && task.milestone != _filterMilestone) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = task.name.toLowerCase().contains(query);
        final matchesNote = task.note?.toLowerCase().contains(query) ?? false;
        final matchesSub = task.subtasks.any((s) => s.name.toLowerCase().contains(query));
        if (!matchesName && !matchesNote && !matchesSub) return false;
      }
      return true;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: isMobile
              ? Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search tasks or notes...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _searchQuery = ''),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
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
                              ...milestones.map((m) => SearchableItem<int?>(
                                    value: m.milestoneId,
                                    label: m.name,
                                    subtitle: 'ID: ${m.milestoneId}${m.deadline != null ? ' • Due: ${m.deadline!.formatted}' : ''}',
                                    leading: const Icon(Icons.flag, size: 16, color: Colors.blue),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _filterMilestone = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Incomplete Only'),
                          selected: _onlyIncomplete,
                          onSelected: (val) => setState(() => _onlyIncomplete = val),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Search input
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search tasks or notes...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Milestone filter (User story 20: Search by name in menu)
                    Expanded(
                      flex: 2,
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
                          ...milestones.map((m) => SearchableItem<int?>(
                                value: m.milestoneId,
                                label: m.name,
                                subtitle: 'ID: ${m.milestoneId}${m.deadline != null ? ' • Due: ${m.deadline!.formatted}' : ''}',
                                leading: const Icon(Icons.flag, size: 16, color: Colors.blue),
                              )),
                        ],
                        onChanged: (val) => setState(() => _filterMilestone = val),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Incomplete toggle
                    FilterChip(
                      label: const Text('Incomplete Only'),
                      selected: _onlyIncomplete,
                      onSelected: (val) => setState(() => _onlyIncomplete = val),
                    ),
                  ],
                ),
        ),

        // Task Tree List
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rtl, size: 64, color: theme.colorScheme.outline),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskCard(
                      key: ValueKey(task.taskId),
                      task: task,
                      controller: widget.controller,
                      depth: 0,
                      onInspectInGraph: widget.onNavigateToGraph,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
