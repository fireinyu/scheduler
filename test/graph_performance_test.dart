import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/controllers/schedule_controller.dart';
import 'package:scheduler/models/milestone.dart';
import 'package:scheduler/models/schedule_data.dart';
import 'package:scheduler/models/schedule_date.dart';
import 'package:scheduler/models/task.dart';
import 'package:scheduler/services/storage_service.dart';
import 'package:scheduler/views/graph_view/full_graph_view.dart';
import 'package:scheduler/views/graph_view/graph_layout_engine.dart';
import 'package:scheduler/views/graph_view/graph_models.dart';
import 'package:scheduler/views/graph_view/graph_painter.dart';
import 'package:scheduler/views/graph_view/task_node_widget.dart';

const due = ScheduleDate(year: 2030, month: 6, day: 15);

class GraphTestStorage extends StorageService {
  final ScheduleData data;
  GraphTestStorage(this.data);

  @override
  Future<ScheduleData> loadSchedule() async => data;

  @override
  Future<void> saveSchedule(ScheduleData schedule) async {}
}

class CountingSchedule extends ScheduleData {
  int deadlineCalculations = 0;
  CountingSchedule({required super.tasks});

  @override
  Map<int, ScheduleDate?> calculateEffectiveDeadlines() {
    deadlineCalculations++;
    return super.calculateEffectiveDeadlines();
  }

  @override
  ScheduleDate? getEffectiveDeadline(Task task, [Set<int>? visited]) =>
      throw StateError('Graph must use batch deadline calculation');
}

void main() {
  test(
    'Batch deadlines preserve inheritance, explicit overrides and cycles',
    () {
      final random = Random(42);
      for (var sample = 0; sample < 20; sample++) {
        final schedule = ScheduleData(
          milestones: [
            Milestone(milestoneId: 1, name: 'Release', deadline: due),
          ],
          tasks: List.generate(
            12,
            (id) => Task(
              taskId: id,
              name: 'Task $id',
              milestone: id % 5 == 0 ? 1 : null,
              deadline: id % 4 == 0
                  ? ScheduleDate(year: 2030, month: 7, day: id + 1)
                  : null,
              dependencies: [
                for (var dep = 0; dep < 12; dep++)
                  if (dep != id && random.nextInt(8) == 0) dep,
              ],
            ),
          ),
        );
        final deadlines = schedule.calculateEffectiveDeadlines();
        for (final task in schedule.tasks) {
          expect(deadlines[task.taskId], schedule.getEffectiveDeadline(task));
        }
      }
      final noDeadlineCycle = ScheduleData(
        tasks: [
          Task(taskId: 1, name: 'A', dependencies: [2]),
          Task(taskId: 2, name: 'B', dependencies: [1, 999]),
        ],
      );
      expect(noDeadlineCycle.calculateEffectiveDeadlines(), {1: null, 2: null});
    },
  );

  for (final shape in ['chain', 'layered', 'nested']) {
    test('Layout handles 500 tasks: $shape', () {
      final tasks = List.generate(
        500,
        (id) => Task(
          taskId: id,
          name: 'Task $id',
          completed: shape == 'chain',
          deadline: id == 499 ? due : null,
          dependencies: shape == 'layered'
              ? [if (id >= 20) id - 20, if (id >= 21) id - 21]
              : [if (id > 0) id - 1],
        ),
      );
      final schedule = CountingSchedule(
        tasks: shape == 'nested'
            ? [tasks.first..subtasks = tasks.skip(1).toList()]
            : tasks,
      );
      final timer = Stopwatch()..start();
      final layout = GraphLayoutEngine.layout(schedule);
      final geometry = GraphGeometry(nodes: layout.nodes, edges: layout.edges);
      expect(geometry.routes.length, layout.edges.length);
      timer.stop();
      // Diagnostic only: wall-clock thresholds are unreliable across CI hosts.
      debugPrint(
        '500-task $shape layout + edge geometry: ${timer.elapsedMilliseconds} ms',
      );
      expect(schedule.deadlineCalculations, 1);
      expect(
        layout.nodes.values.where((n) => n.isTask).length,
        shape == 'nested' ? 1 : 500,
      );
      expect(
        layout.edges.where((e) => e.type == EdgeType.dependency).length,
        shape == 'layered' ? 959 : 499,
      );
      for (final node in layout.nodes.values) {
        expect(node.position.dx.isFinite && node.position.dy.isFinite, isTrue);
        expect(
          node.position.dx + node.size.width,
          lessThan(layout.canvasSize.width),
        );
        expect(
          node.position.dy + node.size.height,
          lessThan(layout.canvasSize.height),
        );
      }
    });
  }

  testWidgets('500-task graph culls cards, reuses layout and refreshes edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final schedule = CountingSchedule(
      tasks: List.generate(500, (id) => Task(taskId: id, name: 'Task $id')),
    );
    final controller = ScheduleController(
      storageService: GraphTestStorage(schedule),
    );
    await controller.init();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => FullGraphView(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    GraphPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<GraphPainter>()
        .single;
    final geometry = painter().geometry;
    expect(schedule.deadlineCalculations, 1);
    expect(find.byType(TaskNodeWidget).evaluate().length, lessThan(15));
    expect(find.text('#499 Task 499'), findsNothing);

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    viewer.transformationController!.value = Matrix4.identity()
      ..setTranslationRaw(0, -81000, 0);
    await tester.pumpAndSettle();
    expect(find.text('#499 Task 499'), findsOneWidget);
    expect(find.text('#0 Task 0'), findsNothing);
    expect(painter().geometry, same(geometry));
    controller.highlightCriteria.dueBefore = due;
    controller.highlightCriteria.minPriority = 1;
    controller.updateHighlightCriteria();
    await tester.pumpAndSettle();
    expect(schedule.deadlineCalculations, 1);
    expect(painter().geometry, same(geometry));

    await tester.tap(find.byTooltip('Reset Zoom'));
    await tester.pumpAndSettle();
    expect(find.text('#0 Task 0'), findsOneWidget);
    viewer.transformationController!.value = Matrix4.diagonal3Values(
      0.2,
      0.2,
      1,
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskNodeWidget).evaluate().length, lessThan(40));
    expect(painter().geometry, same(geometry));
    viewer.transformationController!.value = Matrix4.identity();
    await tester.pumpAndSettle();

    await controller.updateTask(
      schedule.tasks.first.copyWith(name: 'Renamed', deadline: due),
    );
    await tester.pumpAndSettle();
    expect(schedule.deadlineCalculations, 2);
    expect(painter().geometry, isNot(same(geometry)));
    expect(find.text('#0 Renamed'), findsOneWidget);
    await tester.tap(find.text('#0 Renamed'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Task Inspector: #0 Renamed'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to Full Graph'));
    await tester.pumpAndSettle();
    expect(find.text('#0 Renamed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Painter retains crossing edges with both endpoints outside viewport',
    () async {
      final geometry = GraphGeometry(
        nodes: {
          'a': GraphNode(
            id: 'a',
            type: GraphNodeType.task,
            position: const Offset(-300, 50),
            size: const Size(100, 100),
          ),
          'b': GraphNode(
            id: 'b',
            type: GraphNodeType.task,
            position: const Offset(300, 50),
            size: const Size(100, 100),
          ),
        },
        edges: [
          const GraphEdge(fromId: 'a', toId: 'b', type: EdgeType.dependency),
        ],
      );
      final painter = GraphPainter(
        geometry: geometry,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        viewport: const Rect.fromLTWH(0, 0, 200, 200),
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(200, 200));
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      final pixels = (await image.toByteData())!;
      expect(pixels.getUint8((100 * 200 + 100) * 4 + 3), greaterThan(0));
      image.dispose();
      picture.dispose();
      expect(
        painter.shouldRepaint(
          GraphPainter(
            geometry: geometry,
            colorScheme: painter.colorScheme,
            viewport: painter.viewport,
          ),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          GraphPainter(
            geometry: geometry,
            colorScheme: painter.colorScheme,
            viewport: Rect.zero,
          ),
        ),
        isTrue,
      );
    },
  );
}
