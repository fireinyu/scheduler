import 'package:flutter/material.dart';
import '../../controllers/schedule_controller.dart';
import '../../models/task.dart';
import '../../dialogs/task_edit_dialog.dart';
import '../../widgets/obsidian_markdown_view.dart';
import 'deadline_node_widget.dart';

class TaskFocusedGraphView extends StatelessWidget {
  final Task task;
  final ScheduleController controller;
  final VoidCallback onBackToFullGraph;
  final ValueChanged<Task> onSelectNewFocus;

  const TaskFocusedGraphView({
    super.key,
    required this.task,
    required this.controller,
    required this.onBackToFullGraph,
    required this.onSelectNewFocus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = controller.schedule;

    // Refresh task reference in case of updates
    final currentTask = schedule.findTaskById(task.taskId) ?? task;

    // 1. Parent Task
    final parent = schedule.findParentTask(currentTask.taskId);

    // 2. Subtasks
    final subtasks = currentTask.subtasks;

    // 3. Requisite tasks (tasks it depends on)
    final prerequisites = currentTask.dependencies
        .map((depId) => schedule.findTaskById(depId))
        .whereType<Task>()
        .toList();

    // 4. Dependent tasks (tasks that depend on it)
    final dependents = schedule.getTasksDependingOn(currentTask.taskId);

    // 5. Effective deadline
    final deadline = schedule.getEffectiveDeadline(currentTask);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Task Inspector: #${currentTask.taskId} ${currentTask.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Full Graph',
          onPressed: onBackToFullGraph,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Duplicate Task',
            onPressed: () {
              TaskEditDialog.show(
                context: context,
                controller: controller,
                templateTask: currentTask,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Task',
            onPressed: () {
              TaskEditDialog.show(
                context: context,
                controller: controller,
                taskToEdit: currentTask,
              );
            },
          ),
          if (isCompact)
            TextButton.icon(
              icon: const Icon(Icons.fullscreen_exit, size: 18),
              label: const Text('Full Graph'),
              onPressed: onBackToFullGraph,
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.fullscreen_exit, size: 18),
              label: const Text('Full Graph'),
              onPressed: onBackToFullGraph,
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 12 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top: Parent Task (if exists)
                if (parent != null) ...[
                  _buildSectionHeader(
                    context,
                    title: 'Parent Task',
                    icon: Icons.arrow_upward,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: _buildRelatedTaskCard(
                      context,
                      parent,
                      relationBadge: 'Parent Task',
                      badgeColor: theme.colorScheme.tertiary,
                      isDependency: false,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Icon(Icons.keyboard_double_arrow_down, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                ],

                // Middle: Adaptive layout (3 Columns on Desktop/Tablet, Vertical Flow on Mobile)
                if (isCompact) ...[
                  // Requisite Dependencies
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                        context,
                        title: 'Requisite Tasks (Depends On)',
                        icon: Icons.arrow_downward,
                        color: theme.colorScheme.primary,
                        count: prerequisites.length,
                      ),
                      const SizedBox(height: 8),
                      if (prerequisites.isEmpty)
                        _buildEmptyPlaceholder(
                          context,
                          'No requisite dependencies.',
                        )
                      else
                        ...prerequisites.map((req) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildRelatedTaskCard(
                                context,
                                req,
                                relationBadge: 'Pre-requisite (Needs First)',
                                badgeColor: theme.colorScheme.primary,
                                isDependency: true,
                              ),
                            )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Icon(Icons.arrow_downward, color: Colors.grey, size: 22),
                  ),
                  const SizedBox(height: 12),

                  // Center: The Focused Task
                  _buildFocusedTaskCard(context, currentTask, deadline),

                  const SizedBox(height: 12),
                  const Center(
                    child: Icon(Icons.arrow_downward, color: Colors.grey, size: 22),
                  ),
                  const SizedBox(height: 12),

                  // Dependent Tasks
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                        context,
                        title: 'Dependent Tasks (Waiting on this)',
                        icon: Icons.arrow_downward,
                        color: Colors.deepOrange,
                        count: dependents.length,
                      ),
                      const SizedBox(height: 8),
                      if (dependents.isEmpty)
                        _buildEmptyPlaceholder(
                          context,
                          'No tasks currently depend on this task.',
                        )
                      else
                        ...dependents.map((dep) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildRelatedTaskCard(
                                context,
                                dep,
                                relationBadge: 'Dependent (Blocked until complete)',
                                badgeColor: Colors.deepOrange,
                                isDependency: false,
                              ),
                            )),
                    ],
                  ),
                ] else ...[
                  // Desktop 3 Columns [Prerequisites (Left) | CENTER FOCUS TASK | Dependents (Right)]
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Requisite Dependencies
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(
                              context,
                              title: 'Requisite Tasks (Depends On)',
                              icon: Icons.east,
                              color: theme.colorScheme.primary,
                              count: prerequisites.length,
                            ),
                            const SizedBox(height: 8),
                            if (prerequisites.isEmpty)
                              _buildEmptyPlaceholder(
                                context,
                                'No requisite dependencies.',
                              )
                            else
                              ...prerequisites.map((req) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildRelatedTaskCard(
                                      context,
                                      req,
                                      relationBadge: 'Pre-requisite (Needs First)',
                                      badgeColor: theme.colorScheme.primary,
                                      isDependency: true,
                                    ),
                                  )),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                      ),

                      // Center: The Focused Task
                      Expanded(
                        flex: 4,
                        child: _buildFocusedTaskCard(context, currentTask, deadline),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
                      ),

                      // Right Column: Dependent Tasks
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(
                              context,
                              title: 'Dependent Tasks (Waiting on this)',
                              icon: Icons.east,
                              color: Colors.deepOrange,
                              count: dependents.length,
                            ),
                            const SizedBox(height: 8),
                            if (dependents.isEmpty)
                              _buildEmptyPlaceholder(
                                context,
                                'No tasks currently depend on this task.',
                              )
                            else
                              ...dependents.map((dep) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildRelatedTaskCard(
                                      context,
                                      dep,
                                      relationBadge: 'Dependent (Blocked until complete)',
                                      badgeColor: Colors.deepOrange,
                                      isDependency: false,
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),

                // Bottom: Subtasks (if any)
                if (subtasks.isNotEmpty) ...[
                  const Center(
                    child: Icon(Icons.keyboard_double_arrow_down, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader(
                    context,
                    title: 'Subtasks (${subtasks.length})',
                    icon: Icons.subdirectory_arrow_right,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: subtasks.map((sub) {
                      return SizedBox(
                        width: isCompact ? double.infinity : 330,
                        child: _buildRelatedTaskCard(
                          context,
                          sub,
                          relationBadge: 'Subtask',
                          badgeColor: theme.colorScheme.secondary,
                          isDependency: false,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    int? count,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyPlaceholder(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildFocusedTaskCard(
    BuildContext context,
    Task currentTask,
    dynamic deadline,
  ) {
    final theme = Theme.of(context);
    final isOverdue = controller.schedule.isTaskOverdue(currentTask);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
          width: 2.5,
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Focused badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.center_focus_strong, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'FOCUSED TASK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentTask.completed)
                  const Chip(
                    avatar: Icon(Icons.check, size: 16, color: Colors.green),
                    label: Text('Completed', style: TextStyle(color: Colors.green, fontSize: 12)),
                  )
                else if (isOverdue)
                  Chip(
                    avatar: const Icon(Icons.error_outline, size: 16, color: Colors.white),
                    backgroundColor: theme.colorScheme.error,
                    label: const Text(
                      'OVERDUE',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              '#${currentTask.taskId} ${currentTask.name}',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Explicit Deadline Item (User story 16)
            if (deadline != null) ...[
              Row(
                children: [
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DeadlineNodeWidget(
                      deadline: deadline,
                      label: 'Due: ${deadline.formatted}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Priority and Workload
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (currentTask.priority != null)
                  Chip(
                    label: Text('Priority: P${currentTask.priority}'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (currentTask.workload != null)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 16),
                    label: Text('${currentTask.workload} man-hours'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Markdown Note
            if (currentTask.note != null && currentTask.note!.trim().isNotEmpty) ...[
              Text(
                'Note',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ObsidianMarkdownView(
                note: currentTask.note,
                initialExpanded: true,
                allowToggle: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedTaskCard(
    BuildContext context,
    Task relatedTask, {
    required String relationBadge,
    required Color badgeColor,
    required bool isDependency,
  }) {
    final theme = Theme.of(context);
    final deadline = controller.schedule.getEffectiveDeadline(relatedTask);

    return InkWell(
      onTap: () => onSelectNewFocus(relatedTask),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: relatedTask.completed
                ? Colors.green.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      relationBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  relatedTask.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: relatedTask.completed ? Colors.green : theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '#${relatedTask.taskId} ${relatedTask.name}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                decoration: relatedTask.completed ? TextDecoration.lineThrough : null,
              ),
            ),
            if (deadline != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    deadline.formatted,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
