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
  static const double nodeWidth = 260.0;
  static const double taskNodeHeight = 115.0;
  static const double deadlineNodeWidth = 210.0;
  static const double deadlineNodeHeight = 55.0;

  static const double colSpacing = 85.0;
  static const double rowSpacing = 40.0;
  static const double startPaddingX = 60.0;
  static const double startPaddingY = 60.0;

  static GraphLayoutResult layout(ScheduleData schedule) {
    final allTasks = schedule.getAllTasks();
    final nodes = <String, GraphNode>{};
    final edges = <GraphEdge>[];

    if (allTasks.isEmpty) {
      return const GraphLayoutResult(
        nodes: {},
        edges: [],
        canvasSize: Size(800, 600),
      );
    }

    // 1. Calculate ranks (levels) for tasks using topological ordering.
    // Prerequisite dependencies and subtask relationships ensure tasks flow left-to-right.
    final ranks = <int, int>{};

    int computeRank(Task task, Set<int> visiting) {
      if (ranks.containsKey(task.taskId)) return ranks[task.taskId]!;
      if (visiting.contains(task.taskId)) return 0; // Prevent infinite recursion on cycles

      visiting.add(task.taskId);
      int maxDepRank = -1;

      // Dependencies (must be placed before this task)
      for (final depId in task.dependencies) {
        final depTask = schedule.findTaskById(depId);
        if (depTask != null) {
          final r = computeRank(depTask, visiting);
          if (r > maxDepRank) maxDepRank = r;
        }
      }

      // Parent task (parent must be placed before subtasks)
      final parent = schedule.findParentTask(task.taskId);
      if (parent != null) {
        final pr = computeRank(parent, visiting);
        if (pr > maxDepRank) maxDepRank = pr;
      }

      visiting.remove(task.taskId);
      final myRank = maxDepRank + 1;
      ranks[task.taskId] = myRank;
      return myRank;
    }

    for (final task in allTasks) {
      computeRank(task, <int>{});
    }

    // Group tasks by rank
    final taskColumns = <int, List<Task>>{};
    for (final task in allTasks) {
      final r = ranks[task.taskId] ?? 0;
      taskColumns.putIfAbsent(r, () => []).add(task);
    }

    // 2. Create Task Nodes
    for (final task in allTasks) {
      final nodeId = 'task_${task.taskId}';
      nodes[nodeId] = GraphNode(
        id: nodeId,
        type: GraphNodeType.task,
        task: task,
        size: const Size(nodeWidth, taskNodeHeight),
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

    // 4. Create Task Dependency and Subtask Edges
    for (final task in allTasks) {
      final toId = 'task_${task.taskId}';

      // Dependency edges (Requisite -> Task)
      for (final depId in task.dependencies) {
        final fromId = 'task_$depId';
        if (nodes.containsKey(fromId)) {
          edges.add(GraphEdge(
            fromId: fromId,
            toId: toId,
            type: EdgeType.dependency,
            label: 'requisite',
          ));
        }
      }

      // Subtask edges (Parent -> Subtask)
      final parent = schedule.findParentTask(task.taskId);
      if (parent != null) {
        final parentId = 'task_${parent.taskId}';
        if (nodes.containsKey(parentId)) {
          edges.add(GraphEdge(
            fromId: parentId,
            toId: toId,
            type: EdgeType.subtask,
            label: 'subtask',
          ));
        }
      }
    }

    // 5. Sugiyama Layer Ordering (Barycenter Heuristic for Crossing Minimization)
    // Minimizes edge crossings by sorting nodes within each column by the average vertical
    // position of their connected neighbors in adjacent columns.
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
