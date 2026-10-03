import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/main.dart';
import 'package:scheduler/controllers/schedule_controller.dart';
import 'package:scheduler/services/storage_service.dart';
import 'package:scheduler/models/schedule_data.dart';
import 'package:scheduler/dialogs/date_picker_dialog.dart';

class FakeStorageService extends StorageService {
  @override
  Future<void> saveSchedule(ScheduleData schedule) async {}

  @override
  Future<ScheduleData> loadSchedule() async {
    return StorageService.getStarterSchedule();
  }
}

void main() {
  group('Responsive UI Tests across Screen Sizes', () {
    testWidgets('Renders cleanly on mobile phone (360 x 640) without any overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      final controller = ScheduleController(storageService: FakeStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // On mobile screen, 'New Task' is provided via FloatingActionButton
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);

      // Verify list items render properly
      expect(find.text('System Architecture & Schema Design'), findsOneWidget);

      // Verify task filter toolbar on mobile has search and filter chips without overflow
      expect(find.byIcon(Icons.search), findsWidgets);
      expect(find.text('Incomplete Only'), findsOneWidget);

      // Switch to Interactive Graph View tab
      await tester.tap(find.text('Interactive Graph View'));
      await tester.pumpAndSettle();

      // Instruction tip and bottom toolbar are visible and fitted
      expect(find.text('Click any task to inspect relationships • Pan & Zoom freely'), findsOneWidget);
      expect(find.text('Find Task'), findsOneWidget);

      // Open Highlight Filters drawer on mobile by scrolling toolbar to reveal it
      await tester.drag(find.byKey(const Key('graphToolbarScroll')), const Offset(-300, 0));
      await tester.pumpAndSettle();

      final highlightBtn = find.text('Highlight Filters');
      await tester.tap(highlightBtn);
      await tester.pumpAndSettle();
      expect(find.text('Graph Highlights'), findsOneWidget);

      // Close Highlight Filters drawer
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Switch to Task Inspector (Focused Graph View) by selecting task 1
      controller.selectTask(controller.schedule.tasks.first);
      await tester.pumpAndSettle();

      // Should display Task Inspector in mobile adaptive vertical layout
      expect(find.textContaining('Task Inspector: #1'), findsOneWidget);
      expect(find.text('Full Graph'), findsOneWidget);
      expect(find.textContaining('Requisite Tasks'), findsOneWidget);
      expect(find.textContaining('Dependent Tasks'), findsOneWidget);

      // Return to full graph
      await tester.tap(find.text('Full Graph'));
      await tester.pumpAndSettle();
      expect(controller.selectedTask, isNull);
    });

    testWidgets('Renders all modal dialogs without overflow on narrow mobile screens (360 x 640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      final controller = ScheduleController(storageService: FakeStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // 1. TaskEditDialog via FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add Task'), findsOneWidget);
      expect(find.text('Task Name *'), findsOneWidget);
      expect(find.text('Workload (hrs)'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 2. Open Milestones via mobile AppBar PopupMenuButton
      await tester.tap(find.byKey(const Key('appBarOverflowMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Milestones ('));
      await tester.pumpAndSettle();
      expect(find.text('Manage Milestones'), findsOneWidget);
      expect(find.text('New Milestone Name'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 3. Open Team via mobile AppBar PopupMenuButton
      await tester.tap(find.byKey(const Key('appBarOverflowMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Team ('));
      await tester.pumpAndSettle();
      expect(find.text('Manage Teammates'), findsOneWidget);
      expect(find.text('New Teammate Name'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 4. Open Import/Export via mobile AppBar PopupMenuButton
      await tester.tap(find.byKey(const Key('appBarOverflowMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import / Export'));
      await tester.pumpAndSettle();
      expect(find.text('Import / Export Schedule'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 5. ScheduleDatePickerDialog
      final context = tester.element(find.byType(Scaffold).first);
      ScheduleDatePickerDialog.show(context);
      await tester.pumpAndSettle();
      expect(find.text('Select Deadline'), findsOneWidget);
      expect(find.text('Granularity'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SegmentedButton<DateGranularity>),
          matching: find.text('Day'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SegmentedButton<DateGranularity>),
          matching: find.text('Hour'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders desktop layout with full AppBar actions on wide screen (1280 x 800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      final controller = ScheduleController(storageService: FakeStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // On desktop, FAB is not shown; AppBar contains full action buttons
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('New Task'), findsOneWidget);
      expect(find.textContaining('Team ('), findsOneWidget);
      expect(find.textContaining('Milestones ('), findsOneWidget);
      expect(find.text('Import / Export'), findsOneWidget);

      // Open TaskEditDialog on desktop
      await tester.tap(find.text('New Task'));
      await tester.pumpAndSettle();
      expect(find.text('Workload (man-hours)'), findsOneWidget);
      expect(find.text('Priority (higher = urgent)'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
