import 'person.dart';
import 'milestone.dart';
import 'task.dart';
import 'schedule_date.dart';

/// Top-level Schedule container conforming strictly to schedule.json schema.
class ScheduleData {
  List<Person> teammates;
  List<Milestone> milestones;
  List<Task> tasks; // Top-level tasks

  ScheduleData({
    List<Person>? teammates,
    List<Milestone>? milestones,
    List<Task>? tasks,
  })  : teammates = teammates ?? [],
        milestones = milestones ?? [],
        tasks = tasks ?? [];

  factory ScheduleData.fromJson(Map<String, dynamic> json) {
    return ScheduleData(
      teammates: (json['teammates'] as List<dynamic>?)
              ?.map((e) => Person.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((e) => Milestone.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teammates': teammates.map((t) => t.toJson()).toList(),
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
  }

  // Next ID generators
  int get nextTaskId {
    final all = getAllTasks();
    if (all.isEmpty) return 1;
    return all.map((t) => t.taskId).reduce((a, b) => a > b ? a : b) + 1;
  }

  int get nextPersonId {
    if (teammates.isEmpty) return 1;
    return teammates.map((p) => p.personId).reduce((a, b) => a > b ? a : b) + 1;
  }

  int get nextMilestoneId {
    if (milestones.isEmpty) return 1;
    return milestones.map((m) => m.milestoneId).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Flattens all tasks and subtasks into a single list
  List<Task> getAllTasks() {
    final list = <Task>[];
    void collect(Task t) {
      list.add(t);
      for (final sub in t.subtasks) {
        collect(sub);
      }
    }

    for (final task in tasks) {
      collect(task);
    }
    return list;
  }

  /// Finds a task by ID anywhere in the hierarchy
  Task? findTaskById(int id) {
    Task? search(Task t) {
      if (t.taskId == id) return t;
      for (final sub in t.subtasks) {
        final found = search(sub);
        if (found != null) return found;
      }
      return null;
    }

    for (final task in tasks) {
      final found = search(task);
      if (found != null) return found;
    }
    return null;
  }

  /// Finds the parent task of a subtask, or null if top-level or not found
  Task? findParentTask(int childId) {
    Task? search(Task parent) {
      for (final sub in parent.subtasks) {
        if (sub.taskId == childId) return parent;
        final found = search(sub);
        if (found != null) return found;
      }
      return null;
    }

    for (final top in tasks) {
      final found = search(top);
      if (found != null) return found;
    }
    return null;
  }

  /// Returns all tasks that directly list `taskId` in their dependencies
  List<Task> getTasksDependingOn(int taskId) {
    final all = getAllTasks();
    return all.where((t) => t.dependencies.contains(taskId)).toList();
  }

  /// Glossary:
  /// "deadline: A task's deadline can be explicitly set.
  /// Otherwise, the task's deadline is the minimum of the deadlines of the tasks
  /// that depend on it and its milestone"
  ScheduleDate? getEffectiveDeadline(Task task, [Set<int>? visited]) {
    if (task.deadline != null) {
      return task.deadline;
    }

    final cycleCheck = visited ?? <int>{};
    if (cycleCheck.contains(task.taskId)) {
      return null;
    }
    cycleCheck.add(task.taskId);

    ScheduleDate? minDeadline;

    // 1. Milestone deadline
    if (task.milestone != null) {
      for (final m in milestones) {
        if (m.milestoneId == task.milestone && m.deadline != null) {
          minDeadline = m.deadline;
          break;
        }
      }
    }

    // 2. Deadlines of tasks that depend on this task
    final dependents = getTasksDependingOn(task.taskId);
    for (final dep in dependents) {
      final depDeadline = getEffectiveDeadline(dep, Set<int>.from(cycleCheck));
      if (depDeadline != null) {
        if (minDeadline == null || depDeadline.endInstant.isBefore(minDeadline.endInstant)) {
          minDeadline = depDeadline;
        }
      }
    }

    return minDeadline;
  }

  /// Glossary: "A task is overdue if the current datetime exceeds its deadline"
  bool isTaskOverdue(Task task, [DateTime? now]) {
    if (task.completed) return false;
    final deadline = getEffectiveDeadline(task);
    if (deadline == null) return false;
    final current = now ?? DateTime.now();
    return current.isAfter(deadline.endInstant);
  }

  /// User story 12:
  /// "overdue tasks are automatically given the highest priority"
  int getEffectivePriority(Task task, [DateTime? now]) {
    if (isTaskOverdue(task, now)) {
      return 1000000; // Special highest priority
    }
    return task.priority ?? 0;
  }

  /// User story 8:
  /// "Recursively assigns the milestone to each subtask and requisite task without a milestone"
  void assignMilestoneRecursively(Task task, int milestoneId, [Set<int>? visited]) {
    final seen = visited ?? <int>{};
    if (!seen.add(task.taskId)) return;

    task.milestone ??= milestoneId;

    for (final sub in task.subtasks) {
      if (sub.milestone == null) {
        assignMilestoneRecursively(sub, milestoneId, seen);
      }
    }

    for (final depId in task.dependencies) {
      final depTask = findTaskById(depId);
      if (depTask != null && depTask.milestone == null) {
        assignMilestoneRecursively(depTask, milestoneId, seen);
      }
    }
  }

  /// User story 10:
  /// - I am warned before assigning a deadline to a task later than that of a task that depends on it
  /// - I am warned before assigning a deadline to a subtask later than that of the task that contains it
  /// - I am warned before assigning a deadline to a subtask later than that of the milestone it is assigned to
  List<String> checkDeadlineWarnings(Task task, ScheduleDate newDeadline) {
    final warnings = <String>[];
    final newInstant = newDeadline.endInstant;

    // 1. Task that depends on this task
    final dependents = getTasksDependingOn(task.taskId);
    for (final dep in dependents) {
      final depDl = getEffectiveDeadline(dep);
      if (depDl != null && newInstant.isAfter(depDl.endInstant)) {
        warnings.add(
          "Task '${dep.name}' depends on this task and is due on ${depDl.formatted}, "
          "which is earlier than the proposed deadline (${newDeadline.formatted}).",
        );
      }
    }

    // 2. Parent task (if this is a subtask)
    final parent = findParentTask(task.taskId);
    if (parent != null) {
      final parentDl = getEffectiveDeadline(parent);
      if (parentDl != null && newInstant.isAfter(parentDl.endInstant)) {
        warnings.add(
          "Parent task '${parent.name}' deadline (${parentDl.formatted}) is earlier than this subtask deadline (${newDeadline.formatted}).",
        );
      }
    }

    // 3. Milestone deadline (if assigned to milestone)
    if (task.milestone != null) {
      for (final m in milestones) {
        if (m.milestoneId == task.milestone && m.deadline != null) {
          if (newInstant.isAfter(m.deadline!.endInstant)) {
            warnings.add(
              "Task deadline (${newDeadline.formatted}) is later than milestone "
              "'${m.name}' deadline (${m.deadline!.formatted}).",
            );
          }
          break;
        }
      }
    }

    return warnings;
  }

  /// User story 11:
  /// - I am warned before marking a task complete if any of its subtasks or requisite tasks are incomplete
  List<Task> getIncompletePrerequisitesAndSubtasks(Task task) {
    final incomplete = <Task>[];
    final visited = <int>{task.taskId};

    void checkNode(Task t) {
      // Subtasks
      for (final sub in t.subtasks) {
        if (visited.add(sub.taskId)) {
          if (!sub.completed) incomplete.add(sub);
          checkNode(sub);
        }
      }

      // Dependencies (requisite tasks)
      for (final depId in t.dependencies) {
        if (visited.add(depId)) {
          final depTask = findTaskById(depId);
          if (depTask != null) {
            if (!depTask.completed) incomplete.add(depTask);
            checkNode(depTask);
          }
        }
      }
    }

    checkNode(task);
    return incomplete;
  }

  /// User story 11:
  /// - proceeding to do so will also mark all subtasks and requisite tasks as complete
  void markTaskAndPrerequisitesComplete(Task task) {
    task.completed = true;
    final visited = <int>{task.taskId};

    void markNode(Task t) {
      t.completed = true;
      for (final sub in t.subtasks) {
        if (visited.add(sub.taskId)) {
          markNode(sub);
        }
      }
      for (final depId in t.dependencies) {
        if (visited.add(depId)) {
          final depTask = findTaskById(depId);
          if (depTask != null) {
            markNode(depTask);
          }
        }
      }
    }

    markNode(task);
  }

  /// User story 13:
  /// - I am warned before deleting a task which is a dependency of another task
  List<Task> getTasksBlockedBy(Task task) {
    final allSubIds = getAllSubtasksRecursively(task).map((s) => s.taskId).toSet();
    allSubIds.add(task.taskId);

    final blocked = <Task>[];
    for (final other in getAllTasks()) {
      if (!allSubIds.contains(other.taskId)) {
        if (other.dependencies.any((d) => allSubIds.contains(d))) {
          blocked.add(other);
        }
      }
    }
    return blocked;
  }

  /// Returns all subtasks recursively under a task
  List<Task> getAllSubtasksRecursively(Task task) {
    final list = <Task>[];
    void collect(Task t) {
      for (final sub in t.subtasks) {
        list.add(sub);
        collect(sub);
      }
    }
    collect(task);
    return list;
  }

  /// User story 13:
  /// - When I delete a task, its sub-tasks are also deleted
  void deleteTask(int taskId) {
    final task = findTaskById(taskId);
    if (task == null) return;

    final idsToRemove = getAllSubtasksRecursively(task).map((s) => s.taskId).toSet();
    idsToRemove.add(taskId);

    // Remove from parent if subtask, or from root tasks list
    final parent = findParentTask(taskId);
    if (parent != null) {
      parent.subtasks.removeWhere((s) => s.taskId == taskId);
    } else {
      tasks.removeWhere((t) => t.taskId == taskId);
    }

    // Clean up references in all dependencies
    for (final other in getAllTasks()) {
      other.dependencies.removeWhere((depId) => idsToRemove.contains(depId));
    }
  }

  /// Delete person and clear their assignee references
  void deletePerson(int personId) {
    teammates.removeWhere((p) => p.personId == personId);
    for (final task in getAllTasks()) {
      task.assignees.remove(personId);
    }
  }

  /// Delete milestone and clear milestone references on tasks
  void deleteMilestone(int milestoneId) {
    milestones.removeWhere((m) => m.milestoneId == milestoneId);
    for (final task in getAllTasks()) {
      if (task.milestone == milestoneId) {
        task.milestone = null;
      }
    }
  }
}
