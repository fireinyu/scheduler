import 'dart:math';
import 'package:flutter/material.dart';
import 'graph_models.dart';

class GraphPainter extends CustomPainter {
  final Map<String, GraphNode> nodes;
  final List<GraphEdge> edges;
  final ColorScheme colorScheme;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || edges.isEmpty) return;

    // 1. Group outgoing and incoming edges to distribute connection anchors
    // along the right and left boundaries of each node, avoiding overlapping edges.
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

      // Staggered source anchor on the right side of fromNode
      final outList = outEdgesMap[edge.fromId] ?? [edge];
      final outIndex = outList.indexOf(edge);
      final outRatio = (outIndex + 1) / (outList.length + 1);
      final start = Offset(
        fromNode.position.dx + fromNode.size.width,
        fromNode.position.dy + fromNode.size.height * outRatio,
      );

      // Staggered target anchor on the left side of toNode
      final inList = inEdgesMap[edge.toId] ?? [edge];
      final inIndex = inList.indexOf(edge);
      final inRatio = (inIndex + 1) / (inList.length + 1);
      final end = Offset(
        toNode.position.dx,
        toNode.position.dy + toNode.size.height * inRatio,
      );

      // Compute obstacle-avoiding path that routes around intermediate task cards
      final path = _computeObstacleAvoidingPath(start, end, fromNode, toNode);

      // Draw according to edge type (all edges are arrows pointing from left to right)
      switch (edge.type) {
        case EdgeType.dependency:
          final paint = Paint()
            ..color = colorScheme.primary.withValues(alpha: 0.75)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawPath(path, paint);
          _drawArrowhead(canvas, end, color: colorScheme.primary);
          break;

        case EdgeType.subtask:
          final paint = Paint()
            ..color = colorScheme.tertiary.withValues(alpha: 0.8)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke;
          _drawDashedPath(canvas, path, paint, dashWidth: 6, dashSpace: 4);
          _drawArrowhead(canvas, end, color: colorScheme.tertiary);
          break;

        case EdgeType.deadline:
          // User Story 16: "All edges in the graph view are arrow that must point from left to right, including the edges to deadlines"
          final paint = Paint()
            ..color = Colors.deepOrange.withValues(alpha: 0.85)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          _drawDashedPath(canvas, path, paint, dashWidth: 4, dashSpace: 3);
          _drawArrowhead(canvas, end, color: Colors.deepOrange);
          break;
      }
    }
  }

  Path _computeObstacleAvoidingPath(
    Offset start,
    Offset end,
    GraphNode fromNode,
    GraphNode toNode,
  ) {
    final minX = min(start.dx, end.dx) + 8.0;
    final maxX = max(start.dx, end.dx) - 8.0;

    final obstacles = <GraphNode>[];
    for (final node in nodes.values) {
      if (node.id == fromNode.id || node.id == toNode.id) continue;

      // Check if node is horizontally in between start and end
      final nodeLeft = node.position.dx;
      final nodeRight = node.position.dx + node.size.width;

      if (nodeRight > minX && nodeLeft < maxX) {
        final nodeCenterX = (nodeLeft + nodeRight) / 2;
        final t = (nodeCenterX - start.dx) / (end.dx - start.dx);
        final lineY = start.dy + t * (end.dy - start.dy);

        final nodeTop = node.position.dy - 10.0;
        final nodeBottom = node.position.dy + node.size.height + 10.0;

        if (lineY >= nodeTop && lineY <= nodeBottom) {
          obstacles.add(node);
        }
      }
    }

    // Direct path if no obstacles intersect
    if (obstacles.isEmpty) {
      final dx = (end.dx - start.dx).abs() * 0.5;
      return Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + dx, start.dy,
          end.dx - dx, end.dy,
          end.dx, end.dy,
        );
    }

    // Route cleanly around obstacles through clear corridors
    final avgObstacleCenterY = obstacles
            .map((o) => o.position.dy + o.size.height / 2)
            .reduce((a, b) => a + b) /
        obstacles.length;
    final avgEdgeY = (start.dy + end.dy) / 2;

    double corridorY;
    if (avgEdgeY < avgObstacleCenterY) {
      final minTop = obstacles.map((o) => o.position.dy).reduce(min);
      corridorY = minTop - 25.0;
    } else {
      final maxBottom = obstacles.map((o) => o.position.dy + o.size.height).reduce(max);
      corridorY = maxBottom + 25.0;
    }

    final midX = (start.dx + end.dx) / 2;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + 40, start.dy,
        midX - 50, corridorY,
        midX, corridorY,
      )
      ..cubicTo(
        midX + 50, corridorY,
        end.dx - 40, end.dy,
        end.dx, end.dy,
      );
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

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashWidth,
    required double dashSpace,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = min(dashWidth, metric.length - distance);
        final segment = metric.extractPath(distance, distance + length);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
