import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/schedule_data.dart';
import '../../models/highlight_criteria.dart';

class TaskNodeWidget extends StatelessWidget {
  final Task task;
  final ScheduleData schedule;
  final HighlightCriteria highlightCriteria;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const TaskNodeWidget({
    super.key,
    required this.task,
    required this.schedule,
    required this.highlightCriteria,
    this.isSelected = false,
    required this.onTap,
    required this.onDoubleTap,
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
        .map((id) => schedule.teammates.cast().firstWhere(
              (p) => p.personId == id,
              orElse: () => null,
            ))
        .whereType<dynamic>()
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
        // First match color for primary border
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

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 260,
          height: 115,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top row: ID, Name, Status icon
              Row(
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
              ),

              // Middle row: Deadline & Milestone
              Row(
                children: [
                  if (deadline != null) ...[
                    Icon(
                      Icons.event,
                      size: 13,
                      color: isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deadline.formatted,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOverdue ? theme.colorScheme.error : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (milestone != null) ...[
                    const SizedBox(width: 6),
                    Container(
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
                  ],
                ],
              ),

              // Bottom row: Assignee avatars & Highlight criteria indicators
              Row(
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

                  // User story 17: Multi-criteria separate highlight badges
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
