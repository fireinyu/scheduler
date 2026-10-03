import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/models/schedule_date.dart';
import 'package:scheduler/models/person.dart';
import 'package:scheduler/models/milestone.dart';
import 'package:scheduler/models/task.dart';
import 'package:scheduler/models/schedule_data.dart';
import 'package:scheduler/services/schedule_validator.dart';
import 'package:scheduler/services/storage_service.dart';

void main() {
  group('ScheduleDate tests', () {
    test('Date granularity end instants', () {
      // Month granularity: Oct 2026 ends on 2026-10-31 23:59:59.999
      final monthDate = ScheduleDate(year: 2026, month: 10);
      expect(monthDate.day, isNull);
      expect(monthDate.hour, isNull);
      expect(monthDate.endInstant.year, 2026);
      expect(monthDate.endInstant.month, 10);
      expect(monthDate.endInstant.day, 31);
      expect(monthDate.endInstant.hour, 23);
      expect(monthDate.endInstant.minute, 59);

      // Day granularity: Oct 15, 2026 ends on 2026-10-15 23:59:59.999
      final dayDate = ScheduleDate(year: 2026, month: 10, day: 15);
      expect(dayDate.endInstant.day, 15);
      expect(dayDate.endInstant.hour, 23);

      // Hour granularity: Oct 15, 2026 14:00 ends on 2026-10-15 14:59:59.999
      final hourDate = ScheduleDate(year: 2026, month: 10, day: 15, hour: 14);
      expect(hourDate.endInstant.hour, 14);
      expect(hourDate.endInstant.minute, 59);

      // Comparison
      expect(hourDate.compareTo(dayDate), lessThan(0));
      expect(dayDate.compareTo(monthDate), lessThan(0));
    });
  });

  group('Schema compliance and validation', () {
    test('Valid schedule conforms to schema', () {
      final schedule = ScheduleData(
        teammates: [
          Person(personId: 1, name: 'Alice'),
          Person(personId: 2, name: 'Bob'),
        ],
        milestones: [
          Milestone(
            milestoneId: 1,
            name: 'Alpha Release',
            deadline: ScheduleDate(year: 2026, month: 10, day: 20),
          ),
        ],
        tasks: [
          Task(
            taskId: 1,
            name: 'Backend API',
            milestone: 1,
            priority: 2,
            workload: 10,
            deadline: ScheduleDate(year: 2026, month: 10, day: 15, hour: 17),
            dependencies: [],
            assignees: [1],
            completed: false,
            note: '# Note Title\nFirst line of note.\nSecond line.',
            subtasks: [
              Task(
                taskId: 2,
                name: 'Database setup',
                dependencies: [],
                assignees: [2],
                completed: false,
              ),
            ],
          ),
        ],
      );

      final jsonMap = schedule.toJson();
      final errors = ScheduleValidator.validate(jsonMap);
      expect(errors, isEmpty);

      // Round-trip test
      final roundTrip = ScheduleData.fromJson(jsonMap);
      expect(roundTrip.teammates.length, 2);
      expect(roundTrip.milestones.length, 1);
      expect(roundTrip.tasks.length, 1);
      expect(roundTrip.tasks.first.subtasks.length, 1);
      expect(roundTrip.tasks.first.firstLineOfNote, 'Note Title');
    });

    test('Starter schedule conforms strictly to schema', () {
      final starter = StorageService.getStarterSchedule();
      final errors = ScheduleValidator.validate(starter.toJson());
      expect(errors, isEmpty);
    });
  });

  group('User stories business logic', () {
    late ScheduleData schedule;

    setUp(() {
      schedule = ScheduleData(
        teammates: [
          Person(personId: 1, name: 'Alice'),
          Person(personId: 2, name: 'Bob'),
        ],
        milestones: [
          Milestone(
            milestoneId: 1,
            name: 'Milestone 1',
            deadline: ScheduleDate(year: 2026, month: 10, day: 20),
          ),
        ],
        tasks: [
          // Task 1: Requisite for Task 2
          Task(
            taskId: 1,
            name: 'Design DB',
            deadline: ScheduleDate(year: 2026, month: 10, day: 10),
            dependencies: [],
            subtasks: [
              Task(taskId: 3, name: 'Subtask 3-1', dependencies: [], subtasks: [], assignees: [], completed: false),
            ],
            assignees: [1],
            completed: false,
          ),
          // Task 2: Depends on Task 1
          Task(
            taskId: 2,
            name: 'Implement API',
            deadline: ScheduleDate(year: 2026, month: 10, day: 15),
            dependencies: [1],
            subtasks: [],
            assignees: [2],
            completed: false,
          ),
        ],
      );
    });

    test('User Story 8: Recursively assigns milestone to subtasks and requisite tasks without milestone', () {
      final task2 = schedule.findTaskById(2)!;
      final task1 = schedule.findTaskById(1)!;
      final subtask3 = schedule.findTaskById(3)!;

      expect(task2.milestone, isNull);
      expect(task1.milestone, isNull);
      expect(subtask3.milestone, isNull);

      // Assign Milestone 1 to Task 2
      schedule.assignMilestoneRecursively(task2, 1);

      expect(task2.milestone, 1);
      // Requisite task 1 without milestone is assigned
      expect(task1.milestone, 1);
      // Subtask of requisite task without milestone is assigned
      expect(subtask3.milestone, 1);
    });

    test('User Story 10: Deadline warnings for dependent tasks, subtasks, and milestones', () {
      final task1 = schedule.findTaskById(1)!; // Task 2 depends on Task 1 and is due Oct 15
      final subtask3 = schedule.findTaskById(3)!; // Parent Task 1 is due Oct 10

      // Assigning a deadline to Task 1 later than Task 2 (Oct 15) warns
      final warnings1 = schedule.checkDeadlineWarnings(
        task1,
        ScheduleDate(year: 2026, month: 10, day: 18),
      );
      expect(warnings1.any((w) => w.contains('Implement API')), isTrue);

      // Assigning a deadline to Subtask 3 later than Parent Task 1 (Oct 10) warns
      final warningsSub = schedule.checkDeadlineWarnings(
        subtask3,
        ScheduleDate(year: 2026, month: 10, day: 12),
      );
      expect(warningsSub.any((w) => w.contains('Parent task')), isTrue);

      // Assigning deadline later than milestone warns
      subtask3.milestone = 1; // Milestone 1 due Oct 20
      final warningsMs = schedule.checkDeadlineWarnings(
        subtask3,
        ScheduleDate(year: 2026, month: 10, day: 25),
      );
      expect(warningsMs.any((w) => w.contains('Milestone')), isTrue);
    });

    test('User Story 11: Completion warning and cascading completion', () {
      final task2 = schedule.findTaskById(2)!;
      // Task 2 depends on Task 1, which has incomplete subtask 3
      final incomplete = schedule.getIncompletePrerequisitesAndSubtasks(task2);
      expect(incomplete.map((t) => t.taskId).toSet(), containsAll([1, 3]));

      // Mark Task 2 and prerequisites complete
      schedule.markTaskAndPrerequisitesComplete(task2);
      expect(task2.completed, isTrue);
      expect(schedule.findTaskById(1)!.completed, isTrue);
      expect(schedule.findTaskById(3)!.completed, isTrue);
    });

    test('User Story 12: Overdue tasks automatically given highest priority', () {
      final task1 = schedule.findTaskById(1)!;
      task1.priority = 2;

      // Simulated time before deadline (Oct 5, 2026)
      final beforeTime = DateTime(2026, 10, 5);
      expect(schedule.isTaskOverdue(task1, beforeTime), isFalse);
      expect(schedule.getEffectivePriority(task1, beforeTime), 2);

      // Simulated time after deadline (Oct 12, 2026)
      final afterTime = DateTime(2026, 10, 12);
      expect(schedule.isTaskOverdue(task1, afterTime), isTrue);
      expect(schedule.getEffectivePriority(task1, afterTime), 1000000);
    });

    test('User Story 13: Delete task deletes subtasks and warns about dependencies', () {
      final task1 = schedule.findTaskById(1)!;
      // Task 2 depends on Task 1
      final blocked = schedule.getTasksBlockedBy(task1);
      expect(blocked.map((t) => t.taskId), contains(2));

      // Deleting Task 1
      schedule.deleteTask(1);
      expect(schedule.findTaskById(1), isNull);
      expect(schedule.findTaskById(3), isNull); // Subtask also deleted
      // Removed from Task 2 dependencies
      expect(schedule.findTaskById(2)!.dependencies, isEmpty);
    });
  });
}
