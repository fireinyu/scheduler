import 'package:flutter/material.dart';
import 'schedule_date.dart';
import 'task.dart';
import 'schedule_data.dart';

enum HighlightMode {
  matchAll, // Combined AND: task must match all active criteria
  separate, // Each criterion highlighted separately with distinct colors
}

/// Criteria for highlighting parts of the graph view (User story 17)
class HighlightCriteria {
  HighlightMode mode;

  // Criteria filters
  ScheduleDate? dueBefore;
  int? milestoneId;
  bool incompleteOnly;
  int? minPriority;
  Set<int> assigneeIds;
  bool dependenciesCompleted;

  HighlightCriteria({
    this.mode = HighlightMode.separate,
    this.dueBefore,
    this.milestoneId,
    this.incompleteOnly = false,
    this.minPriority,
    Set<int>? assigneeIds,
    this.dependenciesCompleted = false,
  }) : assigneeIds = assigneeIds ?? {};

  bool get hasAnyActiveCriteria =>
      dueBefore != null ||
      milestoneId != null ||
      incompleteOnly ||
      minPriority != null ||
      assigneeIds.isNotEmpty ||
      dependenciesCompleted;

  void clear() {
    dueBefore = null;
    milestoneId = null;
    incompleteOnly = false;
    minPriority = null;
    assigneeIds.clear();
    dependenciesCompleted = false;
  }

  // Colors for separate criteria mode so they do not interfere
  static const Color colorDueBefore = Color(0xFFE65100); // Deep Orange
  static const Color colorMilestone = Color(0xFF6A1B9A); // Purple
  static const Color colorIncomplete = Color(0xFF1565C0); // Blue
  static const Color colorPriority = Color(0xFFC2185B); // Pink
  static const Color colorAssignees = Color(0xFF2E7D32); // Green
  static const Color colorDepsComplete = Color(0xFF00838F); // Cyan
  static const Color colorMatchAll = Color(0xFFFFB300); // Amber gold

  /// Evaluates which criteria match a given task.
  /// Returns a map of criterion name -> Color for matching criteria.
  Map<String, Color> getMatchingCriteria(Task task, ScheduleData schedule) {
    final matches = <String, Color>{};

    // 1. Due at or before specified datetime
    if (dueBefore != null) {
      final taskDl = schedule.getEffectiveDeadline(task);
      if (taskDl != null && !taskDl.endInstant.isAfter(dueBefore!.endInstant)) {
        matches['Due ≤ ${dueBefore!.formatted}'] = colorDueBefore;
      }
    }

    // 2. Belonging to particular milestone
    if (milestoneId != null) {
      if (task.milestone == milestoneId) {
        final ms = schedule.milestones.cast().firstWhere(
              (m) => m.milestoneId == milestoneId,
              orElse: () => null,
            );
        matches['Milestone: ${ms?.name ?? milestoneId}'] = colorMilestone;
      }
    }

    // 3. Incomplete
    if (incompleteOnly) {
      final isIncomplete = !task.completed ||
          schedule.getAllSubtasksRecursively(task).any((s) => !s.completed);
      if (isIncomplete) {
        matches['Incomplete'] = colorIncomplete;
      }
    }

    // 4. Priority at least threshold
    if (minPriority != null) {
      final effPriority = schedule.getEffectivePriority(task);
      if (effPriority >= minPriority!) {
        matches['Priority ≥ $minPriority'] = colorPriority;
      }
    }

    // 5. Assigned to person or set of persons
    if (assigneeIds.isNotEmpty) {
      final hasAssignee = task.assignees.any((a) => assigneeIds.contains(a)) ||
          schedule.getAllSubtasksRecursively(task).any((s) => s.assignees.any((a) => assigneeIds.contains(a)));
      if (hasAssignee) {
        matches['Assigned Team'] = colorAssignees;
      }
    }

    // 6. Dependencies have been completed
    if (dependenciesCompleted) {
      if (task.dependencies.isNotEmpty) {
        final allReqsCompleted = task.dependencies.every((depId) {
          final dep = schedule.findTaskById(depId);
          return dep != null && dep.completed;
        });
        if (allReqsCompleted) {
          matches['Deps Completed'] = colorDepsComplete;
        }
      }
    }

    return matches;
  }

  /// Whether a task matches in current mode
  bool isTaskHighlighted(Task task, ScheduleData schedule) {
    if (!hasAnyActiveCriteria) return false;

    final matches = getMatchingCriteria(task, schedule);

    if (mode == HighlightMode.matchAll) {
      // Must match ALL active criteria
      int activeCount = 0;
      if (dueBefore != null) activeCount++;
      if (milestoneId != null) activeCount++;
      if (incompleteOnly) activeCount++;
      if (minPriority != null) activeCount++;
      if (assigneeIds.isNotEmpty) activeCount++;
      if (dependenciesCompleted) activeCount++;

      return matches.length == activeCount && activeCount > 0;
    } else {
      // Separate: highlighted if it matches at least one active criterion
      return matches.isNotEmpty;
    }
  }
}
