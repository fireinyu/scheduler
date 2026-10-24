import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../controllers/schedule_controller.dart';
import '../../models/task.dart';
import '../../models/schedule_data.dart';
import '../../models/schedule_date.dart';
import '../../widgets/searchable_menu.dart';
import '../../dialogs/task_edit_dialog.dart';
import 'graph_layout_engine.dart';
import 'graph_painter.dart';
import 'task_node_widget.dart';
import 'deadline_node_widget.dart';
import 'highlight_drawer.dart';
import 'task_focused_graph_view.dart';

class FullGraphView extends StatefulWidget {
  final ScheduleController controller;

  const FullGraphView({super.key, required this.controller});

  @override
  State<FullGraphView> createState() => _FullGraphViewState();
}

class _FullGraphViewState extends State<FullGraphView> {
  final TransformationController _transformationController =
      TransformationController();
  bool _showHighlightPanel = false;

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  ScheduleController? _cachedController;
  ScheduleData? _cachedSchedule;
  int? _cachedRevision;
  GraphLayoutResult? _layout;
  GraphGeometry? _geometry;
  Map<int, ScheduleDate?> _effectiveDeadlines = {};

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = widget.controller.schedule;
    final selectedTask = widget.controller.selectedTask;

    // User story 18: If a task is selected, show the Task Focused Graph View
    if (selectedTask != null) {
      return TaskFocusedGraphView(
        task: selectedTask,
        controller: widget.controller,
        onBackToFullGraph: () {
          widget.controller.selectTask(null);
        },
        onSelectNewFocus: (newTask) {
          widget.controller.selectTask(newTask);
        },
      );
    }

    // Otherwise show the Full Graph View
    if (_cachedController != widget.controller ||
        _cachedSchedule != schedule ||
        _cachedRevision != widget.controller.scheduleRevision) {
      _effectiveDeadlines = schedule.calculateEffectiveDeadlines();
      _layout = GraphLayoutEngine.layout(
        schedule,
        effectiveDeadlines: _effectiveDeadlines,
      );
      _geometry = GraphGeometry(nodes: _layout!.nodes, edges: _layout!.edges);
      _cachedController = widget.controller;
      _cachedSchedule = schedule;
      _cachedRevision = widget.controller.scheduleRevision;
    }
    final layoutResult = _layout!;
    // Reuse visible card widgets during pan/zoom; rebuild them for data,
    // highlight or theme changes when this parent builds again.
    final nodeWidgets = <String, Widget>{};

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Graph Canvas
          InteractiveViewer.builder(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.2,
            maxScale: 2.5,
            builder: (context, viewport) {
              final points = [
                viewport.point0,
                viewport.point1,
                viewport.point2,
                viewport.point3,
              ];
              final visibleRect = Rect.fromLTRB(
                points.map((p) => p.x).reduce(math.min),
                points.map((p) => p.y).reduce(math.min),
                points.map((p) => p.x).reduce(math.max),
                points.map((p) => p.y).reduce(math.max),
              ).inflate(80);
              return SizedBox(
                width: layoutResult.canvasSize.width,
                height: layoutResult.canvasSize.height,
                child: Stack(
                  children: [
                    // Background Grid pattern
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridBackgroundPainter(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.15,
                          ),
                          viewport: visibleRect,
                        ),
                      ),
                    ),

                    // Node Widgets (Tasks and Explicit Deadline Items)
                    ...layoutResult.nodes.values
                        .where(
                          (node) =>
                              (node.position & node.size).overlaps(visibleRect),
                        )
                        .map(
                          (node) => nodeWidgets.putIfAbsent(node.id, () {
                            if (node.isDeadline) {
                              return Positioned(
                                key: ValueKey(node.id),
                                left: node.position.dx,
                                top: node.position.dy,
                                child: RepaintBoundary(
                                  child: DeadlineNodeWidget(
                                    deadline: node.deadline,
                                    label: node.label ?? '',
                                  ),
                                ),
                              );
                            } else if (node.task != null) {
                              final task = node.task!;
                              return Positioned(
                                key: ValueKey(node.id),
                                left: node.position.dx,
                                top: node.position.dy,
                                child: RepaintBoundary(
                                  child: TaskNodeWidget(
                                    task: task,
                                    schedule: schedule,
                                    effectiveDeadlines: _effectiveDeadlines,
                                    highlightCriteria:
                                        widget.controller.highlightCriteria,
                                    isSelected:
                                        selectedTask?.taskId == task.taskId,
                                    selectedTaskId: selectedTask?.taskId,
                                    onTap: () {
                                      // User story 18: Select task to see focused graph view
                                      widget.controller.selectTask(task);
                                    },
                                    onDoubleTap: () {
                                      TaskEditDialog.show(
                                        context: context,
                                        controller: widget.controller,
                                        taskToEdit: task,
                                      );
                                    },
                                    onTapSubtask: (subtask) {
                                      widget.controller.selectTask(subtask);
                                    },
                                    onDoubleTapSubtask: (subtask) {
                                      TaskEditDialog.show(
                                        context: context,
                                        controller: widget.controller,
                                        taskToEdit: subtask,
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                        ),

                    // Edges CustomPainter (Dependencies, Subtasks, Deadlines)
                    // Rendered on top of nodes with IgnorePointer so arrows entering parent cards
                    // directly into subtasks are fully visible and unobstructed, without blocking gestures.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: GraphPainter(
                            geometry: _geometry!,
                            viewport: visibleRect,
                            colorScheme: theme.colorScheme,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. Floating Toolbar: Zoom, Highlights, Legend
          Positioned(
            left: 16,
            right: MediaQuery.of(context).size.width < 500 ? 16 : null,
            bottom: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                key: const Key('graphToolbarScroll'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.center_focus_strong),
                      tooltip: 'Reset Zoom',
                      onPressed: _resetZoom,
                    ),
                    const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                    Tooltip(
                      message: 'Search tasks by name in menu (User story 20)',
                      child: TextButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Find Task'),
                        onPressed: () async {
                          final allTasks = schedule.getAllTasks();
                          final pickedTask =
                              await SearchableMenuDialog.show<Task>(
                                context: context,
                                title: 'Find Task in Graph',
                                items: allTasks
                                    .map(
                                      (t) => SearchableItem<Task>(
                                        value: t,
                                        label: '#${t.taskId} ${t.name}',
                                        subtitle: t.deadline != null
                                            ? 'Due: ${t.deadline!.formatted}'
                                            : null,
                                        leading: Icon(
                                          t.completed
                                              ? Icons.check_circle
                                              : Icons.task_alt,
                                          color: t.completed
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                          if (pickedTask != null) {
                            widget.controller.selectTask(pickedTask);
                          }
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                    TextButton.icon(
                      icon: Icon(
                        Icons.highlight,
                        color:
                            widget
                                .controller
                                .highlightCriteria
                                .hasAnyActiveCriteria
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      label: const Text('Highlight Filters'),
                      onPressed: () {
                        setState(() {
                          _showHighlightPanel = !_showHighlightPanel;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. User story 16 & 18 instruction tip
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Click any task to inspect relationships • Pan & Zoom freely',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Highlight Filter Side Panel (User story 17)
          if (_showHighlightPanel)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 12,
                child: HighlightDrawer(
                  controller: widget.controller,
                  onClose: () => setState(() => _showHighlightPanel = false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  final Color color;
  final Rect viewport;

  _GridBackgroundPainter({required this.color, required this.viewport});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const step = 40.0;
    final visible = viewport.intersect(Offset.zero & size);
    if (visible.isEmpty) return;
    for (
      double x = (visible.left / step).floor() * step;
      x <= visible.right;
      x += step
    ) {
      canvas.drawLine(Offset(x, visible.top), Offset(x, visible.bottom), paint);
    }
    for (
      double y = (visible.top / step).floor() * step;
      y <= visible.bottom;
      y += step
    ) {
      canvas.drawLine(Offset(visible.left, y), Offset(visible.right, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) =>
      color != oldDelegate.color || viewport != oldDelegate.viewport;
}
