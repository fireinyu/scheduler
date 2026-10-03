import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/schedule_date.dart';

enum GraphNodeType {
  task,
  deadline,
}

class GraphNode {
  final String id;
  final GraphNodeType type;
  Offset position;
  Size size;

  // Task node data
  final Task? task;

  // Deadline node data
  final ScheduleDate? deadline;
  final String? label;

  GraphNode({
    required this.id,
    required this.type,
    this.position = Offset.zero,
    this.size = const Size(260, 110),
    this.task,
    this.deadline,
    this.label,
  });

  bool get isTask => type == GraphNodeType.task;
  bool get isDeadline => type == GraphNodeType.deadline;
}

enum EdgeType {
  dependency, // Requisite -> Dependent (solid arrow)
  subtask,    // Parent -> Subtask (dashed arrow)
  deadline,   // Deadline item -> Task (dotted line)
}

class GraphEdge {
  final String fromId;
  final String toId;
  final EdgeType type;
  final String? label;

  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.type,
    this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphEdge &&
          runtimeType == other.runtimeType &&
          fromId == other.fromId &&
          toId == other.toId &&
          type == other.type;

  @override
  int get hashCode => Object.hash(fromId, toId, type);
}
