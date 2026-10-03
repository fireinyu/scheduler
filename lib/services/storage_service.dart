import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/schedule_data.dart';
import '../models/person.dart';
import '../models/milestone.dart';
import '../models/task.dart';
import '../models/schedule_date.dart';
import 'schedule_validator.dart';

class StorageService {
  static const String _defaultFileName = 'scheduler_data.json';

  Future<File> get _storageFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_defaultFileName');
  }

  /// Automatically loads the schedule from disk.
  /// If the file does not exist, returns sample starter data illustrating features.
  Future<ScheduleData> loadSchedule() async {
    try {
      final file = await _storageFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            return ScheduleData.fromJson(decoded);
          }
        }
      }
    } catch (e) {
      // Fallback to rootbundle if loading failed
    }
    try {
      final content = await rootBundle.loadString("assets/schedule.json");
      if (content.trim().isNotEmpty) {
        final decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          return ScheduleData.fromJson(decoded);
        }
      }
    } catch (e) {
      // Fallback to starter if loading failed
    }
    return getStarterSchedule();
  }

  /// Automatically saves schedule to disk conforming strictly to schedule.json
  Future<void> saveSchedule(ScheduleData schedule) async {
    try {
      final file = await _storageFile;
      final jsonMap = schedule.toJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonMap);
      await file.writeAsString(jsonStr);
    } catch (e) {
      // Log or handle error
    }
  }

  /// Exports current schedule as a formatted JSON string conforming to schedule.json
  String exportToJsonString(ScheduleData schedule) {
    return const JsonEncoder.withIndent('  ').convert(schedule.toJson());
  }

  /// Exports schedule to a target file
  Future<void> exportToFile(ScheduleData schedule, String filePath) async {
    final jsonStr = exportToJsonString(schedule);
    final file = File(filePath);
    await file.writeAsString(jsonStr);
  }

  /// Imports schedule from JSON string with strict validation
  ScheduleData importFromJsonString(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    final errors = ScheduleValidator.validate(decoded);
    if (errors.isNotEmpty) {
      throw FormatException('Validation errors:\n${errors.join("\n")}');
    }
    return ScheduleData.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  /// Imports schedule from a file
  Future<ScheduleData> importFromFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return importFromJsonString(content);
  }

  /// Sample starter schedule demonstrating user stories:
  /// milestones, teammates, dependencies, subtasks, notes, deadlines, priorities
  static ScheduleData getStarterSchedule() {
    return ScheduleData(
      teammates: [
        Person(personId: 1, name: 'Alice Chen'),
        Person(personId: 2, name: 'Bob Taylor'),
        Person(personId: 3, name: 'Charlie Kim'),
      ],
      milestones: [
        Milestone(
          milestoneId: 1,
          name: 'Beta Release',
          deadline: const ScheduleDate(year: 2026, month: 10, day: 25, hour: 18),
        ),
        Milestone(
          milestoneId: 2,
          name: 'Final Launch',
          deadline: const ScheduleDate(year: 2026, month: 11, day: 15),
        ),
      ],
      tasks: [
        Task(
          taskId: 1,
          name: 'System Architecture & Schema Design',
          workload: 12,
          priority: 3,
          milestone: 1,
          assignees: [1],
          completed: true,
          deadline: const ScheduleDate(year: 2026, month: 10, day: 8, hour: 18),
          note: '# Architecture Overview\nSystem database schemas and JSON contracts.\n- [x] schedule.json schema\n- [x] common.schema.json',
          dependencies: [],
          subtasks: [
            Task(
              taskId: 2,
              name: 'Draft JSON Schema',
              workload: 4,
              assignees: [1],
              completed: true,
              milestone: 1,
              dependencies: [],
              subtasks: [],
              note: 'Strict JSON schema definitions for storage and export.',
            ),
            Task(
              taskId: 3,
              name: 'Validate Storage Pipeline',
              workload: 6,
              assignees: [1, 2],
              completed: true,
              milestone: 1,
              dependencies: [],
              subtasks: [],
              note: 'Validate round-trip serialization and error handling.',
            ),
          ],
        ),
        Task(
          taskId: 4,
          name: 'Core Schedule Engine & Services',
          workload: 20,
          priority: 2,
          milestone: 1,
          assignees: [2],
          completed: true,
          deadline: const ScheduleDate(year: 2026, month: 10, day: 14),
          note: '# Core Engine\nBusiness logic and storage service.\nHandles milestone recursion, warnings, and persistence.',
          dependencies: [1],
          subtasks: [],
        ),
        Task(
          taskId: 5,
          name: 'Interactive DAG Graph Visualizer',
          workload: 25,
          priority: 4,
          milestone: 1,
          assignees: [3],
          completed: false,
          deadline: const ScheduleDate(year: 2026, month: 10, day: 20, hour: 17),
          note: '# Graph Visualization\n- Deadlines shown explicitly as items\n- Multi-criteria highlighting\n- Task-specific focused view',
          dependencies: [1],
          subtasks: [
            Task(
              taskId: 6,
              name: 'Layout & Coordinate Engine',
              workload: 10,
              assignees: [3],
              completed: true,
              milestone: 1,
              dependencies: [],
              subtasks: [],
              note: 'Calculate node positions, ranks, and routed arrows.',
            ),
            Task(
              taskId: 7,
              name: 'Multi-criteria Highlight Layers',
              workload: 12,
              assignees: [3],
              completed: false,
              milestone: 1,
              dependencies: [],
              subtasks: [],
              note: 'Independent non-interfering highlights and combined AND filter.',
            ),
          ],
        ),
        Task(
          taskId: 8,
          name: 'Integration & Delivery Verification',
          workload: 15,
          priority: 3,
          milestone: 1,
          assignees: [1, 2, 3],
          completed: false,
          deadline: const ScheduleDate(year: 2026, month: 10, day: 24),
          note: '# Final QA\nFull end-to-end testing across Windows, macOS, Linux, and Web.',
          dependencies: [4, 5],
          subtasks: [],
        ),
      ],
    );
  }
}
