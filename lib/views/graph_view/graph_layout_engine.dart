import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/schedule_data.dart';
import '../../models/task.dart';
import 'graph_models.dart';

class GraphLayoutResult {
  final Map<String, GraphNode> nodes;
  final List<GraphEdge> edges;
  final Size canvasSize;

  const GraphLayoutResult({
    required this.nodes,
    required this.edges,
    required this.canvasSize,
  });
}

class GraphLayoutEngine {
  static const double nodeWidth = 270.0;
  static const double baseTaskNodeHeight = 115.0;
  static const double deadlineNodeWidth = 210.0;
  static const double deadlineNodeHeight = 55.0;

  static const double colSpacing = 90.0;
  static const double rowSpacing = 40.0;
  static const double startPaddingX = 60.0;
  static const double startPaddingY = 60.0;

  /// Calculates the dynamic height of a task node based on whether it has nested subtasks.
  static double calculateTaskNodeHeight(Task task) {
    if (task.subtasks.isEmpty) {
      return baseTaskNodeHeight;
    }
    // Base parent info (92px) + separator & subtasks header (44px) + bottom buffer (6px) = 142px
    double subtasksHeight = 0;
    for (final sub in task.subtasks) {
      subtasksHeight += _calculateSubtaskCardHeight(sub);
    }
    return 142.0 + subtasksHeight;
  }

  static double _calculateSubtaskCardHeight(Task subtask) {
    // Single subtask card height (47px) + margin bottom (6px) = 53px
    double h = 53.0;
    for (final child in subtask.subtasks) {
      h += _calculateSubtaskCardHeight(child);
    }
    return h;
  }

  static GraphLayoutResult layout(ScheduleData schedule) {
    // Only top-level tasks are graph nodes! Subtasks are nested inside their parent cards.
    final topLevelTasks = schedule
        .getAllTasks()
        .where((t) => schedule.findParentTask(t.taskId) == null)
        .toList();

    final nodes = <String, GraphNode>{};
    final edges = <GraphEdge>[];

    if (topLevelTasks.isEmpty) {
      return const GraphLayoutResult(
        nodes: {},
        edges: [],
        canvasSize: Size(800, 600),
      );
    }

    // Helper to find the top-level parent task of any task
    Task findTopLevelParent(Task t) {
      var current = t;
      while (true) {
        final parent = schedule.findParentTask(current.taskId);
        if (parent == null) return current;
        current = parent;
      }
    }

    // Helper to collect all prerequisite top-level tasks for a top-level task
    // (including dependencies declared on any of its nested subtasks)
    Set<int> getEffectivePrerequisiteTopIds(Task parentTask) {
      final prereqTopIds = <int>{};
      void collect(Task t) {
        for (final depId in t.dependencies) {
          final dep = schedule.findTaskById(depId);
          if (dep != null) {
            final top = findTopLevelParent(dep);
            if (top.taskId != parentTask.taskId) {
              prereqTopIds.add(top.taskId);
            }
          }
        }
        for (final sub in t.subtasks) {
          collect(sub);
        }
      }
      collect(parentTask);
      return prereqTopIds;
    }

    // 1. Calculate ranks (levels) for top-level tasks using topological ordering.
    final ranks = <int, int>{};

    int computeRank(Task task, Set<int> visiting) {
      if (ranks.containsKey(task.taskId)) return ranks[task.taskId]!;
      if (visiting.contains(task.taskId)) return 0; // Avoid cycles

      visiting.add(task.taskId);
      int maxDepRank = -1;

      final prereqTopIds = getEffectivePrerequisiteTopIds(task);
      for (final pId in prereqTopIds) {
        final pTask = topLevelTasks.firstWhere(
          (t) => t.taskId == pId,
          orElse: () => task,
        );
        if (pTask.taskId != task.taskId) {
          final r = computeRank(pTask, visiting);
          if (r > maxDepRank) maxDepRank = r;
        }
      }

      visiting.remove(task.taskId);
      final myRank = maxDepRank + 1;
      ranks[task.taskId] = myRank;
      return myRank;
    }

    for (final task in topLevelTasks) {
      computeRank(task, <int>{});
    }

    // Group top-level tasks by rank
    final taskColumns = <int, List<Task>>{};
    for (final task in topLevelTasks) {
      final r = ranks[task.taskId] ?? 0;
      taskColumns.putIfAbsent(r, () => []).add(task);
    }

    // 2. Create Task Nodes (only for top-level tasks; subtasks are nested inside)
    for (final task in topLevelTasks) {
      final nodeId = 'task_${task.taskId}';
      final h = calculateTaskNodeHeight(task);
      nodes[nodeId] = GraphNode(
        id: nodeId,
        type: GraphNodeType.task,
        task: task,
        size: Size(nodeWidth, h),
      );
    }

    // 3. Create Explicit Deadline Nodes (User Story 16)
    // To ensure all edges point strictly from LEFT to RIGHT without crossing intermediate columns,
    // each deadline group for tasks in column r is placed in column r + 1.
    final columnNodes = <int, List<GraphNode>>{};
    for (final entry in taskColumns.entries) {
      final r = entry.key;
      for (final t in entry.value) {
        columnNodes.putIfAbsent(r, () => []).add(nodes['task_${t.taskId}']!);
      }
    }

    // For each rank r, identify tasks with effective deadlines
    final maxTaskRank = taskColumns.keys.isEmpty ? 0 : taskColumns.keys.reduce(max);
    for (int r = 0; r <= maxTaskRank; r++) {
      final tasksInRank = taskColumns[r] ?? [];
      final deadlinesInRank = <String, List<Task>>{};

      for (final task in tasksInRank) {
        final dl = schedule.getEffectiveDeadline(task);
        if (dl != null) {
          final key = dl.formatted;
          deadlinesInRank.putIfAbsent(key, () => []).add(task);
        }
      }

      for (final dlEntry in deadlinesInRank.entries) {
        final deadlineStr = dlEntry.key;
        final tasksWithDeadline = dlEntry.value;
        final safeKey = deadlineStr.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final dlNodeId = 'deadline_r${r}_$safeKey';

        final dlNode = GraphNode(
          id: dlNodeId,
          type: GraphNodeType.deadline,
          deadline: schedule.getEffectiveDeadline(tasksWithDeadline.first),
          label: deadlineStr,
          size: const Size(deadlineNodeWidth, deadlineNodeHeight),
        );
        nodes[dlNodeId] = dlNode;

        // Place deadline node in rank r + 1 so edge is strictly left-to-right (1 column forward)
        columnNodes.putIfAbsent(r + 1, () => []).add(dlNode);

        // Edges: Task -> Deadline Item (points from left to right)
        for (final t in tasksWithDeadline) {
          edges.add(GraphEdge(
            fromId: 'task_${t.taskId}',
            toId: dlNodeId,
            type: EdgeType.deadline,
            label: 'Due by',
          ));
        }
      }
    }

    // 4. Create Task Dependency Edges between top-level nodes
    final addedEdges = <String>{};
    for (final task in topLevelTasks) {
      final toId = 'task_${task.taskId}';
      final prereqTopIds = getEffectivePrerequisiteTopIds(task);
      for (final pId in prereqTopIds) {
        final fromId = 'task_$pId';
        if (nodes.containsKey(fromId)) {
          final edgeKey = '$fromId->$toId';
          if (!addedEdges.contains(edgeKey)) {
            addedEdges.add(edgeKey);
            edges.add(GraphEdge(
              fromId: fromId,
              toId: toId,
              type: EdgeType.dependency,
              label: 'requisite',
            ));
          }
        }
      }
    }

    // 5. Sugiyama Layer Ordering (Barycenter Heuristic for Crossing Minimization)
    final sortedColKeys = columnNodes.keys.toList()..sort();
    final maxCol = sortedColKeys.isEmpty ? 0 : sortedColKeys.last;

    // Build incoming and outgoing adjacency maps
    final incomingMap = <String, List<String>>{};
    final outgoingMap = <String, List<String>>{};
    for (final edge in edges) {
      outgoingMap.putIfAbsent(edge.fromId, () => []).add(edge.toId);
      incomingMap.putIfAbsent(edge.toId, () => []).add(edge.fromId);
    }

    // Forward sweep: sort column c by predecessors' barycenter
    for (int c = 1; c <= maxCol; c++) {
      final currentLayer = columnNodes[c];
      final prevLayer = columnNodes[c - 1];
      if (currentLayer == null || prevLayer == null) continue;

      final prevIndexMap = <String, int>{};
      for (int i = 0; i < prevLayer.length; i++) {
        prevIndexMap[prevLayer[i].id] = i;
      }

      currentLayer.sort((a, b) {
        final aScore = _calculateBarycenter(incomingMap[a.id] ?? [], prevIndexMap);
        final bScore = _calculateBarycenter(incomingMap[b.id] ?? [], prevIndexMap);
        return aScore.compareTo(bScore);
      });
    }

    // Backward sweep: sort column c by successors' barycenter
    for (int c = maxCol - 1; c >= 0; c--) {
      final currentLayer = columnNodes[c];
      final nextLayer = columnNodes[c + 1];
      if (currentLayer == null || nextLayer == null) continue;

      final nextIndexMap = <String, int>{};
      for (int i = 0; i < nextLayer.length; i++) {
        nextIndexMap[nextLayer[i].id] = i;
      }

      currentLayer.sort((a, b) {
        final aScore = _calculateBarycenter(outgoingMap[a.id] ?? [], nextIndexMap);
        final bScore = _calculateBarycenter(outgoingMap[b.id] ?? [], nextIndexMap);
        return aScore.compareTo(bScore);
      });
    }

    // Final forward pass to lock in optimal alignment
    for (int c = 1; c <= maxCol; c++) {
      final currentLayer = columnNodes[c];
      final prevLayer = columnNodes[c - 1];
      if (currentLayer == null || prevLayer == null) continue;

      final prevIndexMap = <String, int>{};
      for (int i = 0; i < prevLayer.length; i++) {
        prevIndexMap[prevLayer[i].id] = i;
      }

      currentLayer.sort((a, b) {
        final aScore = _calculateBarycenter(incomingMap[a.id] ?? [], prevIndexMap);
        final bScore = _calculateBarycenter(incomingMap[b.id] ?? [], prevIndexMap);
        return aScore.compareTo(bScore);
      });
    }

    // 6. Assign (X, Y) Coordinates
    double currentX = startPaddingX;
    double maxCanvasY = 600.0;

    for (int c = 0; c <= maxCol; c++) {
      final colItems = columnNodes[c] ?? [];
      double currentY = startPaddingY;

      for (final node in colItems) {
        node.position = Offset(currentX, currentY);
        currentY += node.size.height + rowSpacing;
      }

      if (currentY > maxCanvasY) maxCanvasY = currentY;
      currentX += nodeWidth + colSpacing;
    }

    final maxCanvasX = max(currentX + 150, 1100.0);

    return GraphLayoutResult(
      nodes: nodes,
      edges: edges,
      canvasSize: Size(maxCanvasX, max(maxCanvasY + 150, 800.0)),
    );
  }

  static double _calculateBarycenter(
    List<String> neighbors,
    Map<String, int> indexMap,
  ) {
    if (neighbors.isEmpty) return 999.0;
    double score = 0;
    int count = 0;
    for (final id in neighbors) {
      if (indexMap.containsKey(id)) {
        score += indexMap[id]!;
        count++;
      }
    }
    if (count > 0) {
      return score / count;
    }
    return 999.0;
  }
}
