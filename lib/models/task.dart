import 'schedule_date.dart';

/// Represents a task in the schedule.
/// Conforms to common.schema.json#/$defs/task.
class Task {
  final int taskId;
  String name;
  int? workload; // number of man-hours to complete this task
  ScheduleDate? deadline; // Explicitly set deadline
  List<int> dependencies; // IDs of requisite tasks that must be completed first
  List<Task> subtasks; // Smaller tasks that comprise this task
  List<int> assignees; // PersonIds of assigned teammates
  int? milestone; // MilestoneId of assigned milestone
  int? priority; // Higher number means higher priority when not overdue
  bool completed; // Completion status
  String? note; // Additional details in obsidian-flavoured markdown

  Task({
    required this.taskId,
    required this.name,
    this.workload,
    this.deadline,
    List<int>? dependencies,
    List<Task>? subtasks,
    List<int>? assignees,
    this.milestone,
    this.priority,
    this.completed = false,
    this.note,
  })  : dependencies = dependencies ?? [],
        subtasks = subtasks ?? [],
        assignees = assignees ?? [];

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      taskId: json['taskId'] as int,
      name: json['name'] as String,
      workload: json['workload'] as int?,
      deadline: json['deadline'] != null
          ? ScheduleDate.fromJson(Map<String, dynamic>.from(json['deadline'] as Map))
          : null,
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      assignees: (json['assignees'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      milestone: json['milestone'] as int?,
      priority: json['priority'] as int?,
      completed: (json['completed'] as bool?) ?? false,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'taskId': taskId,
      'name': name,
      'dependencies': dependencies,
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'assignees': assignees,
      'completed': completed,
    };
    if (workload != null) map['workload'] = workload;
    if (deadline != null) map['deadline'] = deadline!.toJson();
    if (milestone != null) map['milestone'] = milestone;
    if (priority != null) map['priority'] = priority;
    if (note != null && note!.isNotEmpty) map['note'] = note;
    return map;
  }

  Task copyWith({
    int? taskId,
    String? name,
    int? workload,
    bool clearWorkload = false,
    ScheduleDate? deadline,
    bool clearDeadline = false,
    List<int>? dependencies,
    List<Task>? subtasks,
    List<int>? assignees,
    int? milestone,
    bool clearMilestone = false,
    int? priority,
    bool clearPriority = false,
    bool? completed,
    String? note,
    bool clearNote = false,
  }) {
    return Task(
      taskId: taskId ?? this.taskId,
      name: name ?? this.name,
      workload: clearWorkload ? null : (workload ?? this.workload),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      dependencies: dependencies != null ? List.from(dependencies) : List.from(this.dependencies),
      subtasks: subtasks != null ? List.from(subtasks) : List.from(this.subtasks),
      assignees: assignees != null ? List.from(assignees) : List.from(this.assignees),
      milestone: clearMilestone ? null : (milestone ?? this.milestone),
      priority: clearPriority ? null : (priority ?? this.priority),
      completed: completed ?? this.completed,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  /// First line of note for default compact task display
  String get firstLineOfNote {
    if (note == null || note!.trim().isEmpty) return '';
    final lines = note!.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        // Strip markdown header hashes if present for cleaner preview
        return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      }
    }
    return '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task &&
          runtimeType == other.runtimeType &&
          taskId == other.taskId;

  @override
  int get hashCode => taskId.hashCode;

  @override
  String toString() => 'Task(id: $taskId, name: "$name", completed: $completed)';
}
