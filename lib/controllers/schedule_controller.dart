import 'package:flutter/foundation.dart';
import '../models/schedule_data.dart';
import '../models/task.dart';
import '../models/milestone.dart';
import '../models/person.dart';
import '../models/schedule_date.dart';
import '../models/highlight_criteria.dart';
import '../services/storage_service.dart';

class ScheduleController extends ChangeNotifier {
  final StorageService _storageService;
  late ScheduleData _schedule;
  bool _isLoading = true;
  Task? _selectedTask;
  Task? _lastAddedTask;
  final HighlightCriteria _highlightCriteria = HighlightCriteria();

  ScheduleController({StorageService? storageService})
      : _storageService = storageService ?? StorageService() {
    _schedule = StorageService.getStarterSchedule();
  }

  ScheduleData get schedule => _schedule;
  bool get isLoading => _isLoading;
  Task? get selectedTask => _selectedTask;
  HighlightCriteria get highlightCriteria => _highlightCriteria;

  /// User story: When I add a new task, the values from the most recently added task are used by default
  Task? get mostRecentlyAddedTask {
    if (_lastAddedTask != null) {
      final found = _schedule.findTaskById(_lastAddedTask!.taskId);
      if (found != null) return found;
    }
    final all = _schedule.getAllTasks();
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.taskId > b.taskId ? a : b);
  }

  set mostRecentlyAddedTask(Task? task) {
    _lastAddedTask = task;
    notifyListeners();
  }

  /// User story 14: Whenever I launch the app, the schedule is loaded automatically
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _schedule = await _storageService.loadSchedule();
    } catch (e) {
      _schedule = StorageService.getStarterSchedule();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// User story 14: Whenever I add, delete or edit a task, the changes are saved to disk
  Future<void> _saveToDisk() async {
    await _storageService.saveSchedule(_schedule);
  }

  void selectTask(Task? task) {
    if (task == null) {
      _selectedTask = null;
    } else {
      // Re-fetch by ID from current schedule to ensure fresh reference
      _selectedTask = _schedule.findTaskById(task.taskId);
    }
    notifyListeners();
  }

  /// User story 1: Add named task (top-level)
  Future<void> addTopLevelTask({
    required String name,
    int? workload,
    ScheduleDate? deadline,
    List<int>? dependencies,
    List<int>? assignees,
    int? milestone,
    int? priority,
    String? note,
  }) async {
    final task = Task(
      taskId: _schedule.nextTaskId,
      name: name,
      workload: workload,
      deadline: deadline,
      dependencies: dependencies ?? [],
      assignees: assignees ?? [],
      milestone: milestone,
      priority: priority,
      note: note,
      completed: false,
    );

    // User story 8: if assigned to milestone, recursively assign
    if (milestone != null) {
      _schedule.assignMilestoneRecursively(task, milestone);
    }

    _schedule.tasks.add(task);
    _lastAddedTask = task;
    await _saveToDisk();
    notifyListeners();
  }

  /// User story 3: Add subtask to a task
  Future<void> addSubtask({
    required int parentTaskId,
    required String name,
    int? workload,
    ScheduleDate? deadline,
    List<int>? dependencies,
    List<int>? assignees,
    int? milestone,
    int? priority,
    String? note,
  }) async {
    final parent = _schedule.findTaskById(parentTaskId);
    if (parent == null) return;

    final subtask = Task(
      taskId: _schedule.nextTaskId,
      name: name,
      workload: workload,
      deadline: deadline,
      dependencies: dependencies ?? [],
      assignees: assignees ?? (List.from(parent.assignees)),
      milestone: milestone ?? parent.milestone,
      priority: priority,
      note: note,
      completed: false,
    );

    if (subtask.milestone != null) {
      _schedule.assignMilestoneRecursively(subtask, subtask.milestone!);
    }

    parent.subtasks.add(subtask);
    _lastAddedTask = subtask;
    await _saveToDisk();
    notifyListeners();
  }

  /// Edit existing task
  Future<void> updateTask(Task task) async {
    final existing = _schedule.findTaskById(task.taskId);
    if (existing == null) return;

    existing.name = task.name;
    existing.workload = task.workload;
    existing.deadline = task.deadline;
    existing.dependencies = List.from(task.dependencies);
    existing.assignees = List.from(task.assignees);
    existing.priority = task.priority;
    existing.note = task.note;
    existing.completed = task.completed;

    if (task.milestone != existing.milestone) {
      if (task.milestone != null) {
        _schedule.assignMilestoneRecursively(existing, task.milestone!);
      } else {
        existing.milestone = null;
      }
    }

    if (_selectedTask?.taskId == task.taskId) {
      _selectedTask = existing;
    }

    await _saveToDisk();
    notifyListeners();
  }

  /// User story 11: Set completion status with cascade support
  Future<void> setTaskCompletion(Task task, bool completed, {bool cascade = false}) async {
    final target = _schedule.findTaskById(task.taskId);
    if (target == null) return;

    if (completed && cascade) {
      _schedule.markTaskAndPrerequisitesComplete(target);
    } else {
      target.completed = completed;
    }

    await _saveToDisk();
    notifyListeners();
  }

  /// User story 13: Delete task and its subtasks, remove from dependencies
  Future<void> deleteTask(int taskId) async {
    if (_selectedTask?.taskId == taskId) {
      _selectedTask = null;
    }
    _schedule.deleteTask(taskId);
    await _saveToDisk();
    notifyListeners();
  }

  /// User story 5: Add teammate
  Future<void> addTeammate(String name) async {
    final person = Person(
      personId: _schedule.nextPersonId,
      name: name,
    );
    _schedule.teammates.add(person);
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> updateTeammate(Person person) async {
    final index = _schedule.teammates.indexWhere((p) => p.personId == person.personId);
    if (index != -1) {
      _schedule.teammates[index].name = person.name;
      await _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> deleteTeammate(int personId) async {
    _schedule.deletePerson(personId);
    await _saveToDisk();
    notifyListeners();
  }

  /// User story 7 & 9: Add named milestone with optional deadline
  Future<void> addMilestone(String name, ScheduleDate? deadline) async {
    final milestone = Milestone(
      milestoneId: _schedule.nextMilestoneId,
      name: name,
      deadline: deadline,
    );
    _schedule.milestones.add(milestone);
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> updateMilestone(Milestone milestone) async {
    final index = _schedule.milestones.indexWhere((m) => m.milestoneId == milestone.milestoneId);
    if (index != -1) {
      _schedule.milestones[index].name = milestone.name;
      _schedule.milestones[index].deadline = milestone.deadline;
      await _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> deleteMilestone(int milestoneId) async {
    _schedule.deleteMilestone(milestoneId);
    await _saveToDisk();
    notifyListeners();
  }

  /// User story 15: Export schedule as JSON string
  String exportJson() {
    return _storageService.exportToJsonString(_schedule);
  }

  /// User story 15: Import schedule from JSON string
  Future<void> importJson(String jsonString) async {
    final imported = _storageService.importFromJsonString(jsonString);
    _schedule = imported;
    _selectedTask = null;
    await _saveToDisk();
    notifyListeners();
  }

  /// Reset to starter schedule
  Future<void> resetToDemo() async {
    _schedule = StorageService.getStarterSchedule();
    _selectedTask = null;
    await _saveToDisk();
    notifyListeners();
  }

  /// User story 17: Update highlight criteria
  void updateHighlightCriteria() {
    notifyListeners();
  }

  void clearHighlights() {
    _highlightCriteria.clear();
    notifyListeners();
  }
}
