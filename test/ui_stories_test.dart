import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scheduler/main.dart';
import 'package:scheduler/controllers/schedule_controller.dart';
import 'package:scheduler/services/storage_service.dart';
import 'package:scheduler/models/schedule_data.dart';
import 'package:scheduler/models/highlight_criteria.dart';
import 'package:scheduler/utils/fuzzy_search.dart';
import 'package:scheduler/widgets/searchable_menu.dart';
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
}
