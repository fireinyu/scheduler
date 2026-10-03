import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/person.dart';
import '../../models/schedule_data.dart';
import '../../models/highlight_criteria.dart';
import 'graph_layout_engine.dart';

class TaskNodeWidget extends StatelessWidget {
  final Task task;
  final ScheduleData schedule;
  final HighlightCriteria highlightCriteria;
  final bool isSelected;
  final int? selectedTaskId;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<Task>? onTapSubtask;
  final ValueChanged<Task>? onDoubleTapSubtask;

  const TaskNodeWidget({
    super.key,
    required this.task,
    required this.schedule,
    required this.highlightCriteria,
    this.isSelected = false,
    this.selectedTaskId,
    required this.onTap,
    required this.onDoubleTap,
    this.onTapSubtask,
    this.onDoubleTapSubtask,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = schedule.isTaskOverdue(task);
    final deadline = schedule.getEffectiveDeadline(task);

    // Milestone
    final milestone = task.milestone != null
        ? schedule.milestones.cast().firstWhere(
              (m) => m.milestoneId == task.milestone,
              orElse: () => null,
            )
        : null;

    // Assignees
    final assignees = task.assignees
        .map((id) => schedule.teammates.cast<Person?>().firstWhere(
              (p) => p?.personId == id,
              orElse: () => null,
            ))
        .whereType<Person>()
        .toList();

    // Highlighting logic (User story 17)
    final hasActiveCriteria = highlightCriteria.hasAnyActiveCriteria;
    final isHighlighted = highlightCriteria.isTaskHighlighted(task, schedule);
    final matchingCriteria = highlightCriteria.getMatchingCriteria(task, schedule);

    // Dim if filters active but this task does not match
    final opacity = (!hasActiveCriteria || isHighlighted) ? 1.0 : 0.35;

    // Highlight border / glow
    Border? border;
    List<BoxShadow>? shadows;

    if (isSelected) {
      border = Border.all(color: theme.colorScheme.primary, width: 2.5);
      shadows = [
        BoxShadow(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (hasActiveCriteria && isHighlighted) {
      if (highlightCriteria.mode == HighlightMode.matchAll) {
        border = Border.all(color: HighlightCriteria.colorMatchAll, width: 2.5);
        shadows = [
          BoxShadow(
            color: HighlightCriteria.colorMatchAll.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ];
      } else {
        final firstColor = matchingCriteria.values.first;
        border = Border.all(color: firstColor, width: 2.5);
        shadows = [
          BoxShadow(
            color: firstColor.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ];
      }
    } else if (isOverdue) {
      border = Border.all(color: theme.colorScheme.error, width: 1.8);
    } else if (task.completed) {
      border = Border.all(color: Colors.green.withValues(alpha: 0.6), width: 1.2);
    } else {
      border = Border.all(color: theme.colorScheme.outlineVariant, width: 1);
    }

    final hasSubtasks = task.subtasks.isNotEmpty;
    final nodeHeight = GraphLayoutEngine.calculateTaskNodeHeight(task);

    return Opacity(
      opacity: opacity,
      child: Container(
        width: GraphLayoutEngine.nodeWidth,
        height: nodeHeight,
        decoration: BoxDecoration(
          color: task.completed
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
        ),
        child: hasSubtasks
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clickable Parent Info Area
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        onDoubleTap: onDoubleTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderRow(theme, isOverdue),
                              const SizedBox(height: 6),
                              _buildMiddleRow(theme, deadline, milestone, isOverdue),
                              const SizedBox(height: 6),
                              _buildBottomRow(
                                theme,
                                assignees,
                                hasActiveCriteria,
                                isHighlighted,
                                matchingCriteria,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Divider separating parent task and nested subtasks
                    Divider(
                      height: 12,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),

                    // Subtasks Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_right,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Subtasks (${task.subtasks.length})',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Nested Subtask Cards (Smaller cards showing ONLY name and person assignment)
                    ...task.subtasks.map((sub) => _buildSubtaskCard(context, sub, 0)),
                  ],
                ),
              )
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  onDoubleTap: onDoubleTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeaderRow(theme, isOverdue),
                        _buildMiddleRow(theme, deadline, milestone, isOverdue),
                        _buildBottomRow(
                          theme,
                          assignees,
                          hasActiveCriteria,
                          isHighlighted,
                          matchingCriteria,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderRow(ThemeData theme, bool isOverdue) {
    return Row(
      children: [
        // Status Icon
        Icon(
          task.completed
              ? Icons.check_circle
              : isOverdue
                  ? Icons.error
                  : Icons.radio_button_unchecked,
          size: 16,
          color: task.completed
              ? Colors.green
              : isOverdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.outline,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '#${task.taskId} ${task.name}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              decoration: task.completed ? TextDecoration.lineThrough : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (task.priority != null && task.priority! > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isOverdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOverdue ? 'OVERDUE' : 'P${task.priority}',
              style: TextStyle(
                color: isOverdue
                    ? Colors.white
                    : theme.colorScheme.onSecondaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiddleRow(
    ThemeData theme,
    dynamic deadline,
    dynamic milestone,
    bool isOverdue,
  ) {
    return Row(
      children: [
        if (deadline != null) ...[
          Icon(
            Icons.event,
            size: 13,
            color: isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            deadline.formatted,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOverdue ? theme.colorScheme.error : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (deadline != null && milestone != null) const Spacer(),
        if (milestone != null) ...[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                milestone.name,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomRow(
    ThemeData theme,
    List<Person> assignees,
    bool hasActiveCriteria,
    bool isHighlighted,
    Map<String, Color> matchingCriteria,
  ) {
    return Row(
      children: [
        // Assignee circles
        ...assignees.take(3).map((p) => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: CircleAvatar(
                radius: 9,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            )),
        if (task.workload != null) ...[
          const SizedBox(width: 4),
          Text(
            '${task.workload}h',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
        const Spacer(),

        // Highlight criteria indicators
        if (hasActiveCriteria && isHighlighted) ...[
          if (highlightCriteria.mode == HighlightMode.separate)
            Wrap(
              spacing: 3,
              children: matchingCriteria.entries.map((entry) {
                return Tooltip(
                  message: entry.key,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: HighlightCriteria.colorMatchAll,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MATCH',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// Smaller card for subtasks nested in their parent node,
  /// strictly only showing name and person assignment.
  Widget _buildSubtaskCard(BuildContext context, Task subtask, int depth) {
    final theme = Theme.of(context);
    final isSubSelected = selectedTaskId == subtask.taskId;

    // Person assignment
    final subAssignees = subtask.assignees
        .map((id) => schedule.teammates.cast<Person?>().firstWhere(
              (p) => p?.personId == id,
              orElse: () => null,
            ))
        .whereType<Person>()
        .toList();

    final assigneeNames = subAssignees.isEmpty
        ? 'Unassigned'
        : subAssignees.map((p) => p.name).join(', ');

    return Padding(
      padding: EdgeInsets.only(left: depth * 8.0, bottom: 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapSubtask != null ? () => onTapSubtask!(subtask) : null,
          onDoubleTap: onDoubleTapSubtask != null
              ? () => onDoubleTapSubtask!(subtask)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSubSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSubSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: isSubSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Subtask Name only
                Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 13,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '#${subtask.taskId} ${subtask.name}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // 2. Person Assignment only
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assigneeNames,
                        style: TextStyle(
                          fontSize: 10,
                          color: subAssignees.isEmpty
                              ? theme.colorScheme.outline
                              : theme.colorScheme.onSurfaceVariant,
                          fontStyle: subAssignees.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Recursive sub-subtasks (if any)
                if (subtask.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...subtask.subtasks.map((child) => _buildSubtaskCard(context, child, depth + 1)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
