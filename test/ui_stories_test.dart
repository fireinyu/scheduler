import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/main.dart';
import 'package:scheduler/controllers/schedule_controller.dart';
import 'package:scheduler/services/storage_service.dart';
import 'package:scheduler/models/schedule_data.dart';
import 'package:scheduler/models/highlight_criteria.dart';
import 'package:scheduler/utils/fuzzy_search.dart';
import 'package:scheduler/widgets/searchable_menu.dart';
import 'package:scheduler/models/task.dart';
import 'package:scheduler/views/graph_view/graph_layout_engine.dart';
import 'package:scheduler/views/graph_view/graph_models.dart';

class TestStorageService extends StorageService {
  @override
  Future<void> saveSchedule(ScheduleData schedule) async {}

  @override
  Future<ScheduleData> loadSchedule() async {
    return StorageService.getStarterSchedule();
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('User Story 4: Markdown note shows first line by default and can be expanded',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScheduleController(storageService: TestStorageService());
    await controller.init();

    await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
    await tester.pumpAndSettle();

    // Starter task #1 has first line: "# Architecture Overview", rendered as "Architecture Overview"
    final noteFirstLineFinder = find.text('Architecture Overview');
    expect(noteFirstLineFinder, findsAtLeastNWidgets(1));

    // Tap the markdown note banner to expand it
    await tester.tap(noteFirstLineFinder.first);
    await tester.pumpAndSettle();

    // Full note contents are now expanded
    expect(find.textContaining('schedule.json schema'), findsOneWidget);
  });

  testWidgets('User Story 16: Graph view renders explicit deadline items and task nodes',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScheduleController(storageService: TestStorageService());
    await controller.init();

    await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
    await tester.pumpAndSettle();

    // Switch to Interactive Graph View tab
    final graphTabFinder = find.text('Interactive Graph View');
    expect(graphTabFinder, findsOneWidget);
    await tester.tap(graphTabFinder);
    await tester.pumpAndSettle();

    // Verify tip banner is shown
    expect(find.text('Click any task to inspect relationships • Pan & Zoom freely'), findsOneWidget);

    // Verify explicit deadline nodes are rendered in graph view (User story 16)
    expect(find.text('DEADLINE ITEM'), findsWidgets);

    // Verify all edges in graph layout strictly point from left to right (including edges to deadlines)
    final layoutResult = GraphLayoutEngine.layout(controller.schedule);
    expect(layoutResult.edges, isNotEmpty);

    // Verify that EVERY edge flows strictly from left to right
    for (final edge in layoutResult.edges) {
      final fromNode = layoutResult.nodes[edge.fromId]!;
      final toNode = layoutResult.nodes[edge.toId]!;
      expect(
        fromNode.position.dx,
        lessThan(toNode.position.dx),
        reason: 'Edge ${edge.fromId} -> ${edge.toId} (${edge.type}) must point from left to right',
      );
    }

    // Verify that deadline edges exist, originate at a task, and point rightwards to a deadline node
    final deadlineEdges = layoutResult.edges.where((e) => e.type == EdgeType.deadline).toList();
    expect(deadlineEdges, isNotEmpty);
    for (final dlEdge in deadlineEdges) {
      final fromNode = layoutResult.nodes[dlEdge.fromId]!;
      final toNode = layoutResult.nodes[dlEdge.toId]!;
      expect(fromNode.isTask, isTrue);
      expect(toNode.isDeadline, isTrue);
      expect(fromNode.position.dx, lessThan(toNode.position.dx));
    }
  });

  testWidgets('Subtasks are nested in parent task node in Graph View with smaller cards showing only name and person assignment',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScheduleController(storageService: TestStorageService());
    await controller.init();

    // 1. Verify layout engine nodes:
    // Only top-level tasks exist as GraphNodes. Subtasks (task 2, task 3) must NOT be separate nodes.
    final layoutResult = GraphLayoutEngine.layout(controller.schedule);
    expect(layoutResult.nodes.containsKey('task_1'), isTrue); // Top-level
    expect(layoutResult.nodes.containsKey('task_4'), isTrue); // Top-level
    expect(layoutResult.nodes.containsKey('task_5'), isTrue); // Top-level
    expect(layoutResult.nodes.containsKey('task_8'), isTrue); // Top-level

    // Verify subtasks are NOT separate nodes
    expect(layoutResult.nodes.containsKey('task_2'), isFalse); // Subtask of 1
    expect(layoutResult.nodes.containsKey('task_3'), isFalse); // Subtask of 1
    expect(layoutResult.nodes.containsKey('task_6'), isFalse); // Subtask of 5
    expect(layoutResult.nodes.containsKey('task_7'), isFalse); // Subtask of 5

    // Verify no separate subtask edges connect nodes on canvas
    final subtaskEdges = layoutResult.edges.where((e) => e.type == EdgeType.subtask).toList();
    expect(subtaskEdges, isEmpty);

    // Verify parent node height is dynamically sized larger to accommodate nested subtask cards
    final task1Node = layoutResult.nodes['task_1']!;
    final task4Node = layoutResult.nodes['task_4']!;
    expect(task1Node.size.height, greaterThan(task4Node.size.height));

    // 2. Render FullGraphView and verify UI
    await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
    await tester.pumpAndSettle();

    // Switch to Interactive Graph View
    await tester.tap(find.text('Interactive Graph View'));
    await tester.pumpAndSettle();

    // Verify Parent task card #1 is rendered
    expect(find.text('#1 System Architecture & Schema Design'), findsOneWidget);

    // Verify Nested subtasks headers (both Task 1 and Task 5 have 2 subtasks)
    expect(find.text('Subtasks (2)'), findsNWidgets(2));

    // Verify nested smaller subtask cards show names
    expect(find.text('#2 Draft JSON Schema'), findsOneWidget);
    expect(find.text('#3 Validate Storage Pipeline'), findsOneWidget);
    expect(find.text('#6 Layout & Coordinate Engine'), findsOneWidget);
    expect(find.text('#7 Multi-criteria Highlight Layers'), findsOneWidget);

    // Verify nested smaller subtask cards show person assignment
    expect(find.text('Alice Chen'), findsWidgets); // Assignee for #2
    expect(find.text('Alice Chen, Bob Taylor'), findsOneWidget); // Assignees for #3

    // Verify subtask card does NOT show priority or dates for subtasks
    // (Subtask #2 has workload 4h and no priority, verify no 'P' badge on subtask)
    // Tapping subtask card #2 selects task #2 and opens TaskFocusedGraphView
    await tester.tap(find.text('#2 Draft JSON Schema'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(controller.selectedTask?.taskId, equals(2));
    expect(find.text('Task Inspector: #2 Draft JSON Schema'), findsOneWidget);
  });

  testWidgets('User Story 17: Highlight filters drawer opens and toggles Match All / Separate modes',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScheduleController(storageService: TestStorageService());
    await controller.init();

    await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
    await tester.pumpAndSettle();

    // Switch to Interactive Graph View tab
    await tester.tap(find.text('Interactive Graph View'));
    await tester.pumpAndSettle();

    // Click "Highlight Filters"
    await tester.tap(find.text('Highlight Filters'));
    await tester.pumpAndSettle();

    // Verify Highlight panel is open
    expect(find.text('Graph Highlights'), findsOneWidget);
    expect(find.text('Separate'), findsOneWidget);
    expect(find.text('Match All'), findsOneWidget);
    expect(find.text('Due At or Before'), findsOneWidget);
    expect(find.text('Incomplete tasks only'), findsOneWidget);
    expect(find.text('Priority Threshold'), findsOneWidget);

    // Toggle mode to Match All
    await tester.tap(find.text('Match All'));
    await tester.pumpAndSettle();
    expect(controller.highlightCriteria.mode, equals(HighlightMode.matchAll));

    // Toggle Incomplete filter
    await tester.tap(find.text('Incomplete tasks only'));
    await tester.pumpAndSettle();
    expect(controller.highlightCriteria.incompleteOnly, isTrue);
  });

  testWidgets('User Story 18: Selecting a task displays the Task Focused Graph View',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ScheduleController(storageService: TestStorageService());
    await controller.init();

    await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
    await tester.pumpAndSettle();

    // Switch to Interactive Graph View
    await tester.tap(find.text('Interactive Graph View'));
    await tester.pumpAndSettle();

    // Select task #1 (System Architecture & Schema Design)
    final task1 = controller.schedule.findTaskById(1)!;
    controller.selectTask(task1);
    await tester.pumpAndSettle();

    // Verify Task Focused Inspector is shown (User story 18)
    expect(find.text('Task Inspector: #1 System Architecture & Schema Design'), findsOneWidget);
    expect(find.text('FOCUSED TASK'), findsOneWidget);
    expect(find.text('Requisite Tasks (Depends On)'), findsOneWidget);
    expect(find.text('Dependent Tasks (Waiting on this)'), findsOneWidget);
    expect(find.text('Subtasks (2)'), findsOneWidget);

    // Click "Full Graph" to return to full graph
    await tester.tap(find.text('Full Graph'));
    await tester.pumpAndSettle();

    expect(controller.selectedTask, isNull);
    expect(find.text('Click any task to inspect relationships • Pan & Zoom freely'), findsOneWidget);
  });

  group('User Story 20: Search for items by name in selection menus', () {
    test('FuzzySearch ranks closest matches accurately', () {
      final items = [
        'Final Launch Preparation',
        'Beta Release',
        'Database Schema Design',
        'System Architecture & Schema Design',
        'Frontend UI Polish',
      ];

      // Exact / Prefix match ranks #1
      final betaMatches = FuzzySearch.filterAndRank<String>(
        items: items,
        getName: (s) => s,
        query: 'Beta',
      );
      expect(betaMatches.first, equals('Beta Release'));

      // Word start match ranks high
      final schemaMatches = FuzzySearch.filterAndRank<String>(
        items: items,
        getName: (s) => s,
        query: 'Schema',
      );
      expect(schemaMatches.contains('Database Schema Design'), isTrue);
      expect(schemaMatches.contains('System Architecture & Schema Design'), isTrue);

      // Substring match
      final archMatches = FuzzySearch.filterAndRank<String>(
        items: items,
        getName: (s) => s,
        query: 'Architecture',
      );
      expect(archMatches.first, equals('System Architecture & Schema Design'));

      // Typo tolerance (Levenshtein / subsequence)
      final typoMatches = FuzzySearch.filterAndRank<String>(
        items: items,
        getName: (s) => s,
        query: 'Lnch', // Typo for Launch
      );
      expect(typoMatches.first, equals('Final Launch Preparation'));
    });

    testWidgets('Search milestones by name in milestone filter menu',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScheduleController(storageService: TestStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // Tap Milestone dropdown filter in TaskListView
      final milestoneFieldFinder = find.widgetWithText(SearchableDropdown<int?>, 'All Milestones');
      expect(milestoneFieldFinder, findsOneWidget);

      await tester.tap(milestoneFieldFinder);
      await tester.pumpAndSettle();

      // Search dialog should be visible with search textfield
      expect(find.text('Select Milestone'), findsOneWidget);
      final searchFieldFinder = find.widgetWithText(TextField, 'Search by name...');
      expect(searchFieldFinder, findsOneWidget);

      // Search for "Beta"
      await tester.enterText(searchFieldFinder, 'Beta');
      await tester.pumpAndSettle();

      // Should show closest matches and "Beta Release" at top
      expect(find.textContaining('Showing closest matches'), findsOneWidget);
      final matchTile = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Beta Release'),
      );
      expect(matchTile, findsOneWidget);

      // Tap on Beta Release
      await tester.tap(matchTile);
      await tester.pumpAndSettle();

      // Dropdown now reflects selected Beta Release
      expect(find.widgetWithText(SearchableDropdown<int?>, 'Beta Release'), findsOneWidget);
    });

    testWidgets('Search teammates and requisite dependencies by name in TaskEditDialog',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScheduleController(storageService: TestStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // Tap on "New Task" button to open TaskEditDialog
      await tester.tap(find.text('New Task'));
      await tester.pumpAndSettle();

      expect(find.text('Create Task'), findsOneWidget);

      // Clear template to start with 0 selected assignees
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // 1. Search Teammates (People)
      final teammatesMenuFinder = find.widgetWithText(SearchableMultiSelectMenu<int>, 'Assigned Teammates');
      expect(teammatesMenuFinder, findsOneWidget);

      await tester.tap(teammatesMenuFinder);
      await tester.pumpAndSettle();

      // Dialog opens with search field
      expect(find.text('Assigned Teammates (0 selected)'), findsOneWidget);
      final teammateSearch = find.widgetWithText(TextField, 'Search by name...');
      expect(teammateSearch, findsOneWidget);

      // Search for "Bob"
      await tester.enterText(teammateSearch, 'Bob');
      await tester.pumpAndSettle();

      // Menu updates to show closest match
      expect(find.text('Bob Taylor'), findsOneWidget);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bob Taylor'));
      await tester.pumpAndSettle();

      // Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Bob Taylor chip is now visible in dialog
      expect(find.widgetWithText(Chip, 'Bob Taylor'), findsOneWidget);

      // 2. Search Requisite Dependencies (Tasks)
      // Scroll dialog down to make dependencies visible
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -250));
      await tester.pumpAndSettle();

      final dependenciesMenuFinder = find.widgetWithText(SearchableMultiSelectMenu<int>, 'Requisite Dependencies');
      expect(dependenciesMenuFinder, findsOneWidget);

      await tester.tap(dependenciesMenuFinder);
      await tester.pumpAndSettle();

      expect(find.text('Requisite Dependencies (0 selected)'), findsOneWidget);
      final depSearch = find.widgetWithText(TextField, 'Search by name...');
      expect(depSearch, findsOneWidget);

      // Search for "Architecture"
      await tester.enterText(depSearch, 'Architecture');
      await tester.pumpAndSettle();

      // Closest match "#1 System Architecture & Schema Design" in dialog
      final depItem = find.descendant(
        of: find.byType(Dialog).last,
        matching: find.text('#1 System Architecture & Schema Design'),
      );
      expect(depItem, findsOneWidget);

      await tester.tap(depItem);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Selected task dependency chip is visible
      expect(find.textContaining('System Architecture'), findsWidgets);
    });

    testWidgets('Search tasks by name in Graph View toolbar',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScheduleController(storageService: TestStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // Navigate to Graph View
      await tester.tap(find.text('Interactive Graph View'));
      await tester.pumpAndSettle();

      // Tap "Find Task"
      final findTaskBtn = find.text('Find Task');
      expect(findTaskBtn, findsOneWidget);

      await tester.tap(findTaskBtn);
      await tester.pumpAndSettle();

      // Search dialog opened
      expect(find.text('Find Task in Graph'), findsOneWidget);
      final searchInput = find.widgetWithText(TextField, 'Search by name...');
      expect(searchInput, findsOneWidget);

      // Search for "Visualizer"
      await tester.enterText(searchInput, 'Visualizer');
      await tester.pumpAndSettle();

      // Closest match "#5 Interactive DAG Graph Visualizer" inside the dialog
      final visTile = find.descendant(
        of: find.byType(Dialog),
        matching: find.textContaining('Interactive DAG Graph Visualizer'),
      );
      expect(visTile, findsOneWidget);

      await tester.tap(visTile);
      await tester.pumpAndSettle();

      // Task is selected, opening the Task Focused Inspector
      expect(controller.selectedTask?.taskId, equals(5));
      expect(find.text('Task Inspector: #5 Interactive DAG Graph Visualizer'), findsOneWidget);
    });
  });

  group('Subtask Dependency Arrows in Graph View', () {
    test('GraphLayoutEngine accurately maps subtask dependency edges and layout anchors', () {
      final schedule = StorageService.getStarterSchedule();
      final result = GraphLayoutEngine.layout(schedule);

      // Verify top-level tasks 1 and 4 have nested subtask layouts
      final node1 = result.nodes['task_1']!;
      expect(node1.subtaskLayouts.containsKey(2), isTrue); // subtask 2
      expect(node1.subtaskLayouts.containsKey(3), isTrue); // subtask 3
      expect(node1.subtaskLayouts[2]!.centerY, greaterThan(0));
      expect(node1.subtaskLayouts[3]!.centerY, greaterThan(node1.subtaskLayouts[2]!.centerY));

      final node5 = result.nodes['task_5']!;
      expect(node5.subtaskLayouts.containsKey(6), isTrue); // subtask 6
      expect(node5.subtaskLayouts.containsKey(7), isTrue); // subtask 7

      // Verify dependency edges retain exact fromTaskId and toTaskId
      // In starter schedule: task 4 depends on task 1
      final depEdge1to4 = result.edges.firstWhere(
        (e) => e.fromId == 'task_1' && e.toId == 'task_4',
      );
      expect(depEdge1to4.fromTaskId, equals(1));
      expect(depEdge1to4.toTaskId, equals(4));

      // Create a test schedule where a subtask is specifically depended on
      final customSchedule = ScheduleData(
        tasks: [
          Task(
            taskId: 10,
            name: 'Parent Task A',
            subtasks: [
              Task(taskId: 11, name: 'Subtask A.1'),
              Task(taskId: 12, name: 'Subtask A.2'),
            ],
          ),
          Task(
            taskId: 20,
            name: 'Parent Task B',
            subtasks: [
              // Subtask B.1 depends directly on Subtask A.2
              Task(taskId: 21, name: 'Subtask B.1', dependencies: [12]),
            ],
          ),
        ],
        milestones: [],
        teammates: [],
      );

      final customResult = GraphLayoutEngine.layout(customSchedule);
      final subEdge = customResult.edges.firstWhere(
        (e) => e.fromTaskId == 12 && e.toTaskId == 21,
      );
      expect(subEdge.fromId, equals('task_10'));
      expect(subEdge.toId, equals('task_20'));
      expect(subEdge.fromTaskId, equals(12));
      expect(subEdge.toTaskId, equals(21));

      // Verify subtask layout contains exact position
      final parentANode = customResult.nodes['task_10']!;
      final parentBNode = customResult.nodes['task_20']!;
      expect(parentANode.subtaskLayouts[12], isNotNull);
      expect(parentBNode.subtaskLayouts[21], isNotNull);
    });

    test('GraphLayoutEngine uses expanded horizontal space to prevent overlapping of lines and cards', () {
      final schedule = StorageService.getStarterSchedule();
      final result = GraphLayoutEngine.layout(schedule);

      // Verify generous column spacing is at least 200px
      expect(GraphLayoutEngine.colSpacing, greaterThanOrEqualTo(200.0));

      // Verify that for all forward edges, there is ample horizontal gap (>= 200px) between cards
      for (final edge in result.edges) {
        final fromNode = result.nodes[edge.fromId]!;
        final toNode = result.nodes[edge.toId]!;
        final horizontalGap = toNode.position.dx - (fromNode.position.dx + fromNode.size.width);
        expect(
          horizontalGap,
          greaterThanOrEqualTo(200.0),
          reason: 'Horizontal space between ${edge.fromId} and ${edge.toId} must be at least 200px',
        );
      }

      // Verify canvas width expands with the generous spacing
      expect(result.canvasSize.width, greaterThan(1500.0));
    });

    test('GraphLayoutEngine places completed tasks closer to the left and incomplete tasks closer to the right', () {
      final schedule = StorageService.getStarterSchedule();
      final result = GraphLayoutEngine.layout(schedule);

      final task1 = result.nodes['task_1']!; // Completed
      final task4 = result.nodes['task_4']!; // Completed
      final task5 = result.nodes['task_5']!; // Incomplete
      final task8 = result.nodes['task_8']!; // Incomplete

      // Completed tasks appear closer to the left (smaller X)
      // Incomplete tasks appear closer to the right (larger X)
      expect(task1.position.dx, lessThan(task4.position.dx));
      expect(task4.position.dx, lessThan(task5.position.dx));
      expect(task5.position.dx, lessThan(task8.position.dx));

      // All completed tasks are strictly to the left of incomplete tasks
      expect(task1.position.dx, lessThan(task5.position.dx));
      expect(task4.position.dx, lessThan(task8.position.dx));

      // Disconnected branches: incomplete tasks without dependencies start to the right of completed tasks
      final customSchedule = ScheduleData(
        tasks: [
          Task(taskId: 101, name: 'Done Task', completed: true),
          Task(taskId: 102, name: 'Pending Independent Task', completed: false),
        ],
      );
      final customResult = GraphLayoutEngine.layout(customSchedule);
      final doneNode = customResult.nodes['task_101']!;
      final pendingNode = customResult.nodes['task_102']!;
      expect(
        doneNode.position.dx,
        lessThan(pendingNode.position.dx),
        reason: 'Independent incomplete task must appear to the right of completed task',
      );

      // Verify User Story 16 invariant: all edges point strictly from left to right
      for (final edge in result.edges) {
        final fromNode = result.nodes[edge.fromId]!;
        final toNode = result.nodes[edge.toId]!;
        expect(
          fromNode.position.dx,
          lessThan(toNode.position.dx),
          reason: 'All graph edges must point strictly from left to right (${edge.fromId} -> ${edge.toId})',
        );
      }
    });
  });

  group('Default Values and Duplicating Tasks User Story', () {
    testWidgets('New task uses values from the most recently added task by default',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScheduleController(storageService: TestStorageService());
      await controller.init();

      // Add a distinctive task to be the most recently added task
      await controller.addTopLevelTask(
        name: 'Alpha Feature',
        workload: 18,
        priority: 4,
        note: 'Important architectural notes for Alpha',
        milestone: 1,
        assignees: [2],
      );

      final recent = controller.mostRecentlyAddedTask;
      expect(recent, isNotNull);
      expect(recent!.name, equals('Alpha Feature'));
      expect(recent.workload, equals(18));
      expect(recent.priority, equals(4));

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // Tap on "New Task" button to open TaskEditDialog
      await tester.tap(find.text('New Task'));
      await tester.pumpAndSettle();

      // Verify dialog opened with default values from the most recently added task
      expect(find.text('Create Task'), findsOneWidget);
      expect(find.text('Alpha Feature (Copy)'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('Alpha Feature'), findsWidgets);
    });

    testWidgets('User can select a task from template dropdown to duplicate its values',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScheduleController(storageService: TestStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // Open "New Task" dialog
      await tester.tap(find.text('New Task'));
      await tester.pumpAndSettle();

      // Clear template first
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Name field is now empty
      expect(find.text(''), findsWidgets);

      // Tap template dropdown to pick another task to duplicate
      final templateDropdown = find.text('None (Blank Task)');
      expect(templateDropdown, findsOneWidget);
      await tester.tap(templateDropdown);
      await tester.pumpAndSettle();

      // Select Task 1: "System Architecture & Schema Design"
      final task1Option = find.textContaining('System Architecture & Schema Design').last;
      await tester.tap(task1Option);
      await tester.pumpAndSettle();

      // Values from Task 1 are now prefilled
      expect(find.text('System Architecture & Schema Design (Copy)'), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // Task 1 workload is 12h
      expect(find.text('3'), findsOneWidget);  // Task 1 priority is 3
    });

    testWidgets('Duplicate Task option from TaskCard context menu duplicates values',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScheduleController(storageService: TestStorageService());
      await controller.init();

      await tester.pumpWidget(ProjectSchedulerApp(controller: controller));
      await tester.pumpAndSettle();

      // Find first task's action popup menu
      final popupMenuFinder = find.byTooltip('Task Actions').first;
      await tester.tap(popupMenuFinder);
      await tester.pumpAndSettle();

      // Tap "Duplicate Task"
      expect(find.text('Duplicate Task'), findsOneWidget);
      await tester.tap(find.text('Duplicate Task'));
      await tester.pumpAndSettle();

      // TaskEditDialog opened with duplicate pre-fill
      expect(find.text('Create Task'), findsOneWidget);
      expect(find.textContaining('(Copy)'), findsOneWidget);
      expect(find.text('Duplicate values from task:'), findsOneWidget);
    });
  });
}
