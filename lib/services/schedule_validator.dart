/// Validates JSON maps against schedule.json and common.schema.json.
class ScheduleValidator {
  /// Validates a root schedule JSON map. Returns empty list if valid, or list of errors.
  static List<String> validate(dynamic root) {
    final errors = <String>[];

    if (root is! Map<String, dynamic>) {
      return ['Root JSON must be an object (map)'];
    }

    // Required top-level keys: teammates, milestones, tasks
    for (final req in ['teammates', 'milestones', 'tasks']) {
      if (!root.containsKey(req)) {
        errors.add('Missing required top-level property: "$req"');
      }
    }

    if (root['teammates'] != null) {
      if (root['teammates'] is! List) {
        errors.add('"teammates" must be an array');
      } else {
        final list = root['teammates'] as List;
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is! Map) {
            errors.add('teammates[$i] must be an object');
          } else {
            _validatePerson(Map<String, dynamic>.from(item), 'teammates[$i]', errors);
          }
        }
      }
    }

    if (root['milestones'] != null) {
      if (root['milestones'] is! List) {
        errors.add('"milestones" must be an array');
      } else {
        final list = root['milestones'] as List;
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is! Map) {
            errors.add('milestones[$i] must be an object');
          } else {
            _validateMilestone(Map<String, dynamic>.from(item), 'milestones[$i]', errors);
          }
        }
      }
    }

    if (root['tasks'] != null) {
      if (root['tasks'] is! List) {
        errors.add('"tasks" must be an array');
      } else {
        final list = root['tasks'] as List;
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is! Map) {
            errors.add('tasks[$i] must be an object');
          } else {
            _validateTask(Map<String, dynamic>.from(item), 'tasks[$i]', errors);
          }
        }
      }
    }

    return errors;
  }

  static void _validatePerson(Map<String, dynamic> item, String path, List<String> errors) {
    if (!item.containsKey('personId') || item['personId'] is! int) {
      errors.add('$path: "personId" must be an integer');
    }
    if (!item.containsKey('name') || item['name'] is! String) {
      errors.add('$path: "name" must be a string');
    }
  }

  static void _validateMilestone(Map<String, dynamic> item, String path, List<String> errors) {
    if (!item.containsKey('milestoneId') || item['milestoneId'] is! int) {
      errors.add('$path: "milestoneId" must be an integer');
    }
    if (!item.containsKey('name') || item['name'] is! String) {
      errors.add('$path: "name" must be a string');
    }
    if (item.containsKey('deadline') && item['deadline'] != null) {
      if (item['deadline'] is! Map) {
        errors.add('$path: "deadline" must be an object');
      } else {
        _validateDate(Map<String, dynamic>.from(item['deadline'] as Map), '$path.deadline', errors);
      }
    }
  }

  static void _validateTask(Map<String, dynamic> item, String path, List<String> errors) {
    if (!item.containsKey('taskId') || item['taskId'] is! int) {
      errors.add('$path: "taskId" must be an integer');
    }
    if (!item.containsKey('name') || item['name'] is! String) {
      errors.add('$path: "name" must be a string');
    }
    if (!item.containsKey('dependencies') || item['dependencies'] is! List) {
      errors.add('$path: "dependencies" must be an array');
    } else {
      final deps = item['dependencies'] as List;
      for (var j = 0; j < deps.length; j++) {
        if (deps[j] is! int) {
          errors.add('$path.dependencies[$j] must be an integer');
        }
      }
    }
    if (!item.containsKey('subtasks') || item['subtasks'] is! List) {
      errors.add('$path: "subtasks" must be an array');
    } else {
      final subs = item['subtasks'] as List;
      for (var j = 0; j < subs.length; j++) {
        if (subs[j] is! Map) {
          errors.add('$path.subtasks[$j] must be an object');
        } else {
          _validateTask(Map<String, dynamic>.from(subs[j] as Map), '$path.subtasks[$j]', errors);
        }
      }
    }
    if (!item.containsKey('assignees') || item['assignees'] is! List) {
      errors.add('$path: "assignees" must be an array');
    } else {
      final assignees = item['assignees'] as List;
      for (var j = 0; j < assignees.length; j++) {
        if (assignees[j] is! int) {
          errors.add('$path.assignees[$j] must be an integer');
        }
      }
    }
    if (!item.containsKey('completed') || item['completed'] is! bool) {
      errors.add('$path: "completed" must be a boolean');
    }

    if (item.containsKey('workload') && item['workload'] != null && item['workload'] is! int) {
      errors.add('$path: "workload" must be an integer');
    }
    if (item.containsKey('milestone') && item['milestone'] != null && item['milestone'] is! int) {
      errors.add('$path: "milestone" must be an integer');
    }
    if (item.containsKey('priority') && item['priority'] != null && item['priority'] is! int) {
      errors.add('$path: "priority" must be an integer');
    }
    if (item.containsKey('note') && item['note'] != null && item['note'] is! String) {
      errors.add('$path: "note" must be a string');
    }
    if (item.containsKey('deadline') && item['deadline'] != null) {
      if (item['deadline'] is! Map) {
        errors.add('$path: "deadline" must be an object');
      } else {
        _validateDate(Map<String, dynamic>.from(item['deadline'] as Map), '$path.deadline', errors);
      }
    }
  }

  static void _validateDate(Map<String, dynamic> item, String path, List<String> errors) {
    if (!item.containsKey('year') || item['year'] is! int) {
      errors.add('$path: "year" must be an integer');
    }
    if (!item.containsKey('month') || item['month'] is! int) {
      errors.add('$path: "month" must be an integer');
    } else {
      final m = item['month'] as int;
      if (m < 1 || m > 12) {
        errors.add('$path: "month" must be between 1 and 12');
      }
    }
    if (item.containsKey('day') && item['day'] != null) {
      if (item['day'] is! int) {
        errors.add('$path: "day" must be an integer');
      } else {
        final d = item['day'] as int;
        if (d < 1 || d > 31) {
          errors.add('$path: "day" must be between 1 and 31');
        }
      }
    }
    if (item.containsKey('hour') && item['hour'] != null) {
      if (item['hour'] is! int) {
        errors.add('$path: "hour" must be an integer');
      } else {
        final h = item['hour'] as int;
        if (h < 0 || h > 23) {
          errors.add('$path: "hour" must be between 0 and 23');
        }
      }
    }
  }
}
