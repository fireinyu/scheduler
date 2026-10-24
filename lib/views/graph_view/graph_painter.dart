import 'dart:math';

import 'package:flutter/material.dart';

import 'graph_models.dart';

/// Geometry is prepared once per layout, independently of theme and viewport.
class GraphGeometry {
  final Map<String, GraphNode> nodes;
  final List<GraphEdge> edges;
  late final List<GraphRoute> routes = _prepareRoutes();

  GraphGeometry({required this.nodes, required this.edges});

  List<GraphRoute> _prepareRoutes() {
    final routes = <GraphRoute>[];
    // 1. Group outgoing and incoming edges to distribute connection anchors
    // along the boundaries of each node, avoiding overlapping edges.
    final outEdgesMap = <String, List<GraphEdge>>{};
    final inEdgesMap = <String, List<GraphEdge>>{};

    for (final edge in edges) {
      if (nodes.containsKey(edge.fromId) && nodes.containsKey(edge.toId)) {
        outEdgesMap.putIfAbsent(edge.fromId, () => []).add(edge);
        inEdgesMap.putIfAbsent(edge.toId, () => []).add(edge);
      }
    }

    // Sort outgoing edges by destination node's vertical position
    for (final entry in outEdgesMap.entries) {
      entry.value.sort((a, b) {
        final toA = nodes[a.toId]!;
        final toB = nodes[b.toId]!;
        return toA.position.dy.compareTo(toB.position.dy);
      });
    }

    // Sort incoming edges by source node's vertical position
    for (final entry in inEdgesMap.entries) {
      entry.value.sort((a, b) {
        final fromA = nodes[a.fromId]!;
        final fromB = nodes[b.fromId]!;
        return fromA.position.dy.compareTo(fromB.position.dy);
      });
    }

    // 2. Render each edge
    for (final edge in edges) {
      final fromNode = nodes[edge.fromId];
      final toNode = nodes[edge.toId];
      if (fromNode == null || toNode == null) continue;

      final outList = outEdgesMap[edge.fromId] ?? [edge];
      final inList = inEdgesMap[edge.toId] ?? [edge];
      final isIntraNode = fromNode.id == toNode.id;

      // Anchors: subtasks start or end directly at the subtask card
      final start = _getAnchorPoint(
        node: fromNode,
        taskId: edge.fromTaskId,
        isSource: true,
        groupEdges: outList,
        edge: edge,
        isIntraNode: isIntraNode,
      );

      final end = _getAnchorPoint(
        node: toNode,
        taskId: edge.toTaskId,
        isSource: false,
        groupEdges: inList,
        edge: edge,
        isIntraNode: isIntraNode,
      );

      // Compute obstacle-avoiding path that routes cleanly
      final path = _computeObstacleAvoidingPath(
        start,
        end,
        fromNode,
        toNode,
        edge,
      );

      routes.add(GraphRoute(edge.type, path, end));
    }
    return routes;
  }

  Offset _getAnchorPoint({
    required GraphNode node,
    int? taskId,
    required bool isSource,
    required List<GraphEdge> groupEdges,
    required GraphEdge edge,
    required bool isIntraNode,
  }) {
    if (node.isDeadline) {
      final index = groupEdges.indexOf(edge);
      final ratio = (index + 1) / (groupEdges.length + 1);
      return Offset(
        isSource ? node.position.dx + node.size.width : node.position.dx,
        node.position.dy + node.size.height * ratio,
      );
    }

    // Check if taskId refers to a subtask inside this node
    if (taskId != null && node.subtaskLayouts.containsKey(taskId)) {
      final sub = node.subtaskLayouts[taskId]!;
      // Find position among edges connected to the exact same subtask
      final sameSubEdges = groupEdges
          .where((e) => (isSource ? e.fromTaskId : e.toTaskId) == taskId)
          .toList();
      final index = sameSubEdges.indexOf(edge);
      final count = sameSubEdges.length;
      final subJitter = count > 1 ? (index - (count - 1) / 2.0) * 10.0 : 0.0;
      final y = node.position.dy + sub.centerY + subJitter;

      if (isIntraNode) {
        return Offset(node.position.dx + 10.0 + sub.depth * 8.0, y);
      }

      if (isSource) {
        // Arrow starts at the subtask directly (right edge of subtask card)
        return Offset(node.position.dx + node.size.width - 10.0, y);
      } else {
        // Arrow ends at the subtask directly (left edge of subtask card)
        return Offset(node.position.dx + 10.0 + sub.depth * 8.0, y);
      }
    }

    // Default to parent task anchor
    final sameTargetEdges = groupEdges
        .where(
          (e) => (isSource ? e.fromTaskId : e.toTaskId) == node.task?.taskId,
        )
        .toList();
    final index = sameTargetEdges.indexOf(edge);
    final count = sameTargetEdges.isNotEmpty
        ? sameTargetEdges.length
        : groupEdges.length;
    final parentIdx = index >= 0 ? index : groupEdges.indexOf(edge);

    if (node.task != null && node.task!.subtasks.isNotEmpty) {
      // Parent with subtasks: parent info area is at top ~74px (center ~45px)
      final jitter = count > 1 ? (parentIdx - (count - 1) / 2.0) * 12.0 : 0.0;
      final y = node.position.dy + 45.0 + jitter;
      return Offset(
        isSource ? node.position.dx + node.size.width : node.position.dx,
        y,
      );
    }

    final ratio = (parentIdx + 1) / (count + 1);
    return Offset(
      isSource ? node.position.dx + node.size.width : node.position.dx,
      node.position.dy + node.size.height * ratio,
    );
  }

  Path _computeObstacleAvoidingPath(
    Offset start,
    Offset end,
    GraphNode fromNode,
    GraphNode toNode,
    GraphEdge edge,
  ) {
    if (fromNode.id == toNode.id) {
      // Intra-node subtask dependency curve
      final loopLeft = min(start.dx, end.dx) - 30.0;
      return Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(loopLeft, start.dy, loopLeft, end.dy, end.dx, end.dy);
    }

    // Identify intermediate nodes whose horizontal span lies strictly between start and end columns
    final minX = min(start.dx, end.dx) + 15.0;
    final maxX = max(start.dx, end.dx) - 15.0;

    final intermediateNodes = nodes.values.where((node) {
      if (node.id == fromNode.id || node.id == toNode.id) return false;
      final nodeLeft = node.position.dx;
      final nodeRight = node.position.dx + node.size.width;
      return nodeRight > minX && nodeLeft < maxX;
    }).toList();

    // Direct path if no intermediate nodes exist between columns
    if (intermediateNodes.isEmpty) {
      final dx = (end.dx - start.dx).abs() * 0.5;
      return Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx + dx, start.dy, end.dx - dx, end.dy, end.dx, end.dy);
    }

    // Multi-column spanning edge: route cleanly around intermediate cards through corridors
    final minTop = intermediateNodes.map((o) => o.position.dy).reduce(min);
    final maxBottom = intermediateNodes
        .map((o) => o.position.dy + o.size.height)
        .reduce(max);
    final firstInterLeft = intermediateNodes
        .map((o) => o.position.dx)
        .reduce(min);
    final lastInterRight = intermediateNodes
        .map((o) => o.position.dx + o.size.width)
        .reduce(max);

    // Channels immediately after start node and before end node
    final firstChannelX = (start.dx + firstInterLeft) / 2.0;
    final lastChannelX = (lastInterRight + end.dx) / 2.0;

    // Decide whether to route above or below intermediate cards
    final distAbove = (start.dy - minTop).abs() + (end.dy - minTop).abs();
    final distBelow = (maxBottom - start.dy).abs() + (maxBottom - end.dy).abs();
    final goAbove = distAbove <= distBelow;

    // Distribute multiple skipping lines across distinct lanes to prevent line overlap
    final laneOffset = (edge.hashCode.abs() % 4) * 8.0;
    final corridorY = goAbove
        ? minTop - 28.0 - laneOffset
        : maxBottom + 28.0 + laneOffset;

    final dx1 = (firstChannelX - start.dx).abs() * 0.5;
    final dx2 = (end.dx - lastChannelX).abs() * 0.5;

    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + dx1,
        start.dy,
        firstChannelX - dx1,
        corridorY,
        firstChannelX,
        corridorY,
      )
      ..lineTo(lastChannelX, corridorY)
      ..cubicTo(
        lastChannelX + dx2,
        corridorY,
        end.dx - dx2,
        end.dy,
        end.dx,
        end.dy,
      );
  }
}

class GraphRoute {
  final EdgeType type;
  final Path path;
  final Offset end;
  late final Rect bounds = path
      .getBounds()
      .expandToInclude(Rect.fromCenter(center: end, width: 22, height: 14))
      .inflate(2);
  // Dash extraction is relatively expensive on long edges. Do it only once,
  // when the route first becomes visible.
  late final Path strokePath = _buildStrokePath();

  GraphRoute(this.type, this.path, this.end);

  Path _buildStrokePath() {
    if (type == EdgeType.dependency) return path;
    final dashWidth = type == EdgeType.deadline ? 4.0 : 6.0;
    final dashSpace = type == EdgeType.deadline ? 3.0 : 4.0;
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      for (
        double distance = 0;
        distance < metric.length;
        distance += dashWidth + dashSpace
      ) {
        dashed.addPath(
          metric.extractPath(
            distance,
            min(distance + dashWidth, metric.length),
          ),
          Offset.zero,
        );
      }
    }
    return dashed;
  }
}

class GraphPainter extends CustomPainter {
  final GraphGeometry geometry;
  final ColorScheme colorScheme;
  final Rect? viewport;

  GraphPainter({
    required this.geometry,
    required this.colorScheme,
    this.viewport,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = {
      EdgeType.dependency: colorScheme.primary,
      EdgeType.subtask: colorScheme.tertiary,
      EdgeType.deadline: Colors.deepOrange,
    };
    final paints = {
      for (final type in EdgeType.values)
        type: Paint()
          ..color = colors[type]!.withValues(
            alpha: type == EdgeType.subtask ? 0.8 : 0.85,
          )
          ..strokeWidth = type == EdgeType.subtask ? 1.8 : 2.0
          ..style = PaintingStyle.stroke,
    };
    for (final route in geometry.routes) {
      // Test the whole curve, so connections crossing the viewport still show
      // even when both endpoint cards are offscreen.
      if (viewport != null && !route.bounds.overlaps(viewport!)) continue;
      canvas.drawPath(route.strokePath, paints[route.type]!);
      _drawArrowhead(canvas, route.end, color: colors[route.type]!);
    }
  }

  void _drawArrowhead(
    Canvas canvas,
    Offset point, {
    required Color color,
    double length = 10.0,
    double width = 5.5,
  }) {
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Arrowhead points strictly from LEFT to RIGHT into point
    final arrowPath = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(point.dx - length, point.dy - width)
      ..lineTo(point.dx - length * 0.75, point.dy)
      ..lineTo(point.dx - length, point.dy + width)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      colorScheme != oldDelegate.colorScheme ||
      viewport != oldDelegate.viewport;
}
