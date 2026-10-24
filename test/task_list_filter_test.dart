import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/controllers/schedule_controller.dart';
import 'package:scheduler/models/milestone.dart';
import 'package:scheduler/models/person.dart';
import 'package:scheduler/models/schedule_data.dart';
import 'package:scheduler/models/task.dart';
import 'package:scheduler/services/storage_service.dart';
import 'package:scheduler/views/task_list_view.dart';
import 'package:scheduler/widgets/task_card.dart';

class FilterStorage extends StorageService {
  @override
  Future<void> saveSchedule(ScheduleData schedule) async {}

  @override
  Future<ScheduleData> loadSchedule() async => ScheduleData(
    teammates: [
      Person(personId: 1, name: 'Alice'),
      Person(personId: 2, name: 'Bob'),
    ],
    milestones: [Milestone(milestoneId: 1, name: 'Release')],
    tasks: [
      Task(
        taskId: 1,
        name: 'Parent',
        subtasks: [
          Task(taskId: 2, name: 'Shared work', assignees: [1, 2], milestone: 1),
          Task(taskId: 3, name: 'Bob work', assignees: [2]),
          Task(
            taskId: 4,
            name: 'Alice finished',
            assignees: [1],
            completed: true,
          ),
        ],
      ),
      Task(taskId: 5, name: 'Completed root', assignees: [1], completed: true),
      Task(taskId: 6, name: 'Unassigned'),
    ],
  );
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('Person and status filters work at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ScheduleController(storageService: FilterStorage());
      await controller.init();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => TaskListView(
                controller: controller,
                onNavigateToGraph: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Set<int> shown() => tester
          .widgetList<TaskCard>(find.byType(TaskCard))
          .map((card) => card.task.taskId)
          .toSet();
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      expect(shown(), {1, 2, 3, 6});

      Future<void> choosePerson(String name) async {
        await tester.tap(find.byKey(const Key('taskPersonFilter')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, name));
        await tester.pumpAndSettle();
      }

      await choosePerson('Alice');
      expect(shown(), {1, 2});
      // Cancelling the menu must keep the selected person.
      await tester.tap(find.byKey(const Key('taskPersonFilter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(shown(), {1, 2});

      await tester.tap(find.text('Incomplete Only'));
      await tester.pumpAndSettle();
      expect(shown(), {1, 2, 4, 5});
      await tester.tap(find.text('Incomplete Only'));
      await tester.pumpAndSettle();
      await choosePerson('Bob');
      expect(shown(), {1, 2, 3});

      await tester.tap(find.text('All Milestones'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Release'));
      await tester.pumpAndSettle();
      expect(shown(), {1, 2});
      await tester.enterText(find.byType(TextField), 'no matches');
      await tester.pumpAndSettle();
      expect(find.text('No tasks match the filter.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(shown(), {1, 2});
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      await tester.tap(find.text('Release').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'All Milestones'));
      await tester.pumpAndSettle();
      await choosePerson('All People');
      expect(shown(), {1, 2, 3, 6});
      await choosePerson('Bob');
      await controller.deleteTeammate(2);
      await tester.pumpAndSettle();
      expect(find.text('All People'), findsOneWidget);
      expect(shown(), {1, 2, 3, 6});
      expect(tester.takeException(), isNull);
    });
  }
}
