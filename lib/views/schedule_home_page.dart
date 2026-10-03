import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../dialogs/import_export_dialog.dart';
import '../dialogs/milestone_dialog.dart';
import '../dialogs/task_edit_dialog.dart';
import '../dialogs/teammate_dialog.dart';
import 'graph_view/full_graph_view.dart';
import 'task_list_view.dart';

class ScheduleHomePage extends StatefulWidget {
  final ScheduleController controller;

  const ScheduleHomePage({super.key, required this.controller});

  @override
  State<ScheduleHomePage> createState() => _ScheduleHomePageState();
}

class _ScheduleHomePageState extends State<ScheduleHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToGraph() {
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final isCompact = screenWidth < 1000;
        final isMobile = screenWidth < 600;

        return Scaffold(
          floatingActionButton: isMobile && _tabController.index == 0
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('New Task'),
                  onPressed: () {
                    TaskEditDialog.show(
                      context: context,
                      controller: widget.controller,
                    );
                  },
                )
              : null,
          appBar: AppBar(
            elevation: 1,
            centerTitle: false,
            title: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month),
                  SizedBox(width: 8),
                  Text(
                    'Project Scheduler',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(
                  icon: Icon(Icons.format_list_bulleted),
                  text: 'Task Hierarchy Tree',
                ),
                Tab(
                  icon: Icon(Icons.account_tree),
                  text: 'Interactive Graph View',
                ),
              ],
            ),
            actions: [
              if (!isMobile) ...[
                // Manage Teammates
                if (isCompact)
                  IconButton(
                    icon: const Icon(Icons.people_outline),
                    tooltip: 'Team (${widget.controller.schedule.teammates.length})',
                    onPressed: () => TeammateDialog.show(context, widget.controller),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: Text('Team (${widget.controller.schedule.teammates.length})'),
                    onPressed: () => TeammateDialog.show(context, widget.controller),
                  ),
                const SizedBox(width: 6),

                // Manage Milestones
                if (isCompact)
                  IconButton(
                    icon: const Icon(Icons.flag_outlined),
                    tooltip: 'Milestones (${widget.controller.schedule.milestones.length})',
                    onPressed: () => MilestoneDialog.show(context, widget.controller),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: Text('Milestones (${widget.controller.schedule.milestones.length})'),
                    onPressed: () => MilestoneDialog.show(context, widget.controller),
                  ),
                const SizedBox(width: 6),

                // Import / Export
                if (isCompact)
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: 'Import / Export',
                    onPressed: () => ImportExportDialog.show(context, widget.controller),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_vert, size: 18),
                    label: const Text('Import / Export'),
                    onPressed: () => ImportExportDialog.show(context, widget.controller),
                  ),
                const SizedBox(width: 8),

                // Add Task CTA
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Task'),
                  onPressed: () {
                    TaskEditDialog.show(
                      context: context,
                      controller: widget.controller,
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],

              // Options menu (Teammates, Milestones, Import/Export on mobile, plus Reset Demo)
              PopupMenuButton<String>(
                key: const Key('appBarOverflowMenu'),
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    switch (val) {
                      case 'teammates':
                        TeammateDialog.show(context, widget.controller);
                        break;
                      case 'milestones':
                        MilestoneDialog.show(context, widget.controller);
                        break;
                      case 'import_export':
                        ImportExportDialog.show(context, widget.controller);
                        break;
                      case 'reset_demo':
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Reset to Starter Project?'),
                            content: const Text(
                              'This will replace the current schedule with the starter sample project.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  widget.controller.resetToDemo();
                                  Navigator.of(ctx).pop();
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        );
                        break;
                    }
                  });
                },
                itemBuilder: (ctx) => [
                  if (isMobile) ...[
                    PopupMenuItem(
                      value: 'teammates',
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Team (${widget.controller.schedule.teammates.length})')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'milestones',
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Milestones (${widget.controller.schedule.milestones.length})')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'import_export',
                      child: Row(
                        children: [
                          Icon(Icons.swap_vert, size: 18),
                          SizedBox(width: 8),
                          Expanded(child: Text('Import / Export')),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  const PopupMenuItem(
                    value: 'reset_demo',
                    child: Row(
                      children: [
                        Icon(Icons.restart_alt, size: 18),
                        SizedBox(width: 8),
                        Expanded(child: Text('Reset to Demo Project')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // Prevent conflict with graph pan
            children: [
              TaskListView(
                controller: widget.controller,
                onNavigateToGraph: _navigateToGraph,
              ),
              FullGraphView(
                controller: widget.controller,
              ),
            ],
          ),
        );
      },
    );
  }
}
