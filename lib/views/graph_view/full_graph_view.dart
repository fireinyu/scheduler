import 'package:flutter/material.dart';
import '../../controllers/schedule_controller.dart';
import '../../models/task.dart';
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
  final TransformationController _transformationController = TransformationController();
  bool _showHighlightPanel = false;

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    _transformationController.value = _transformationController.value * Matrix4.diagonal3Values(1.2, 1.2, 1.0);
  }

  void _zoomOut() {
    _transformationController.value = _transformationController.value * Matrix4.diagonal3Values(0.8, 0.8, 1.0);
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
    final layoutResult = GraphLayoutEngine.layout(schedule);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive Graph Canvas
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.2,
            maxScale: 2.5,
            child: SizedBox(
              width: layoutResult.canvasSize.width,
              height: layoutResult.canvasSize.height,
              child: Stack(
                children: [
                  // Background Grid pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridBackgroundPainter(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
                      ),
                    ),
                  ),

                  // Edges CustomPainter (Dependencies, Subtasks, Deadlines)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GraphPainter(
                        nodes: layoutResult.nodes,
                        edges: layoutResult.edges,
                        colorScheme: theme.colorScheme,
                      ),
                    ),
                  ),

                  // Node Widgets (Tasks and Explicit Deadline Items)
                  ...layoutResult.nodes.values.map((node) {
                    if (node.isDeadline) {
                      return Positioned(
                        left: node.position.dx,
                        top: node.position.dy,
                        child: DeadlineNodeWidget(
                          deadline: node.deadline,
                          label: node.label ?? '',
                        ),
                      );
                    } else if (node.task != null) {
                      final task = node.task!;
                      return Positioned(
                        left: node.position.dx,
                        top: node.position.dy,
                        child: TaskNodeWidget(
                          task: task,
                          schedule: schedule,
                          highlightCriteria: widget.controller.highlightCriteria,
                          isSelected: selectedTask?.taskId == task.taskId,
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
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
          ),

          // 2. Floating Toolbar: Zoom, Highlights, Legend
          Positioned(
            left: 16,
            bottom: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_in),
                    tooltip: 'Zoom In',
                    onPressed: _zoomIn,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out),
                    tooltip: 'Zoom Out',
                    onPressed: _zoomOut,
                  ),
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
                      final pickedTask = await SearchableMenuDialog.show<Task>(
                        context: context,
                        title: 'Find Task in Graph',
                        items: allTasks
                            .map((t) => SearchableItem<Task>(
                                  value: t,
                                  label: '#${t.taskId} ${t.name}',
                                  subtitle: t.deadline != null
                                      ? 'Due: ${t.deadline!.formatted}'
                                      : null,
                                  leading: Icon(
                                    t.completed ? Icons.check_circle : Icons.task_alt,
                                    color: t.completed
                                        ? Colors.green
                                        : theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ))
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
                      color: widget.controller.highlightCriteria.hasAnyActiveCriteria
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    label: Text(
                      widget.controller.highlightCriteria.hasAnyActiveCriteria
                          ? 'Highlights Active'
                          : 'Highlight Filters',
                    ),
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

          // 3. User story 16 & 18 instruction tip
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  Icon(Icons.touch_app, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Click any task to inspect relationships • Pan & Zoom freely',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
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
                child: HighlightDrawer(controller: widget.controller),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  final Color color;

  _GridBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) =>
      color != oldDelegate.color;
}
