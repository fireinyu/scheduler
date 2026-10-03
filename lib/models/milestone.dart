import 'schedule_date.dart';

/// Represents a milestone of the project.
/// Conforms to common.schema.json#/$defs/milestone.
class Milestone {
  final int milestoneId;
  String name;
  ScheduleDate? deadline;

  Milestone({
    required this.milestoneId,
    required this.name,
    this.deadline,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    return Milestone(
      milestoneId: json['milestoneId'] as int,
      name: json['name'] as String,
      deadline: json['deadline'] != null
          ? ScheduleDate.fromJson(Map<String, dynamic>.from(json['deadline'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'milestoneId': milestoneId,
      'name': name,
    };
    if (deadline != null) {
      map['deadline'] = deadline!.toJson();
    }
    return map;
  }

  Milestone copyWith({
    int? milestoneId,
    String? name,
    ScheduleDate? deadline,
    bool clearDeadline = false,
  }) {
    return Milestone(
      milestoneId: milestoneId ?? this.milestoneId,
      name: name ?? this.name,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Milestone &&
          runtimeType == other.runtimeType &&
          milestoneId == other.milestoneId;

  @override
  int get hashCode => milestoneId.hashCode;

  @override
  String toString() => 'Milestone(milestoneId: $milestoneId, name: $name, deadline: $deadline)';
}
