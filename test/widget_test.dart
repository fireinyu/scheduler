import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/main.dart';
import 'package:scheduler/controllers/schedule_controller.dart';
import 'package:scheduler/services/storage_service.dart';
import 'package:scheduler/models/schedule_data.dart';

class FakeStorageService extends StorageService {
  @override
  Future<void> saveSchedule(ScheduleData schedule) async {}

  @override
  Future<ScheduleData> loadSchedule() async {
    return StorageService.getStarterSchedule();
  }
}

void main() {
  testWidgets('ProjectSchedulerApp smoke test', (WidgetTester tester) async {
    // Set standard desktop surface size for test
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScheduleController(storageService: FakeStorageService());
    await controller.init();

    await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
    await tester.pump();

    // Verify AppBar title and tabs
    expect(find.text('Project Scheduler'), findsOneWidget);
    expect(find.text('Task Hierarchy Tree'), findsOneWidget);
    expect(find.text('Interactive Graph View'), findsOneWidget);

    // Verify starter tasks rendered
    expect(find.text('System Architecture & Schema Design'), findsOneWidget);
    expect(find.text('New Task'), findsOneWidget);
  });
}
