import 'package:flutter/material.dart';
import '../../controllers/schedule_controller.dart';
import '../../models/highlight_criteria.dart';
import '../../widgets/searchable_menu.dart';
import '../../dialogs/date_picker_dialog.dart';

class HighlightDrawer extends StatefulWidget {
  final ScheduleController controller;

  const HighlightDrawer({super.key, required this.controller});

  @override
  State<HighlightDrawer> createState() => _HighlightDrawerState();
}

class _HighlightDrawerState extends State<HighlightDrawer> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final criteria = widget.controller.highlightCriteria;
    final schedule = widget.controller.schedule;
    final milestones = schedule.milestones;
    final teammates = schedule.teammates;

    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        width: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  Icon(Icons.highlight, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Graph Highlights',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (criteria.hasAnyActiveCriteria)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          widget.controller.clearHighlights();
                        });
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ),

          // Scrollable options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Combination Mode (User story 17)
                Text(
                  'Highlight Mode',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SegmentedButton<HighlightMode>(
                  segments: const [
                    ButtonSegment(
                      value: HighlightMode.separate,
                      label: Text('Separate'),
                      tooltip: 'Highlight each criterion separately with distinct colors',
                    ),
                    ButtonSegment(
                      value: HighlightMode.matchAll,
                      label: Text('Match All'),
                      tooltip: 'Highlight only tasks matching ALL active criteria (AND)',
                    ),
                  ],
                  selected: {criteria.mode},
                  onSelectionChanged: (set) {
                    setState(() {
                      criteria.mode = set.first;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),

                // 1. Due at or before specified datetime
                _buildCriterionHeader(
                  title: 'Due At or Before',
                  color: HighlightCriteria.colorDueBefore,
                  isActive: criteria.dueBefore != null,
                  onClear: () {
                    setState(() {
                      criteria.dueBefore = null;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    criteria.dueBefore != null
                        ? criteria.dueBefore!.formatted
                        : 'Any deadline',
                    style: TextStyle(
                      fontWeight: criteria.dueBefore != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 14),
                    label: Text(criteria.dueBefore == null ? 'Set' : 'Change'),
                    onPressed: () async {
                      final picked = await ScheduleDatePickerDialog.show(
                        context,
                        initialDate: criteria.dueBefore,
                      );
                      if (picked != null) {
                        setState(() {
                          criteria.dueBefore = picked;
                          widget.controller.updateHighlightCriteria();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Belonging to particular milestone
                _buildCriterionHeader(
                  title: 'Belonging to Milestone',
                  color: HighlightCriteria.colorMilestone,
                  isActive: criteria.milestoneId != null,
                  onClear: () {
                    setState(() {
                      criteria.milestoneId = null;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                SearchableDropdown<int?>(
                  labelText: 'Milestone',
                  isDense: true,
                  value: criteria.milestoneId,
                  items: [
                    const SearchableItem<int?>(
                      value: null,
                      label: 'None (All)',
                      isNoneOption: true,
                    ),
                    ...milestones.map((m) => SearchableItem<int?>(
                          value: m.milestoneId,
                          label: m.name,
                          subtitle: 'ID: ${m.milestoneId}',
                          leading: const Icon(Icons.flag, size: 16, color: Colors.blue),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      criteria.milestoneId = val;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 3. Incomplete tasks
                _buildCriterionHeader(
                  title: 'Completion Status',
                  color: HighlightCriteria.colorIncomplete,
                  isActive: criteria.incompleteOnly,
                  onClear: () {
                    setState(() {
                      criteria.incompleteOnly = false;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Incomplete tasks only'),
                  value: criteria.incompleteOnly,
                  onChanged: (val) {
                    setState(() {
                      criteria.incompleteOnly = val;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // 4. Priority >= threshold
                _buildCriterionHeader(
                  title: 'Priority Threshold',
                  color: HighlightCriteria.colorPriority,
                  isActive: criteria.minPriority != null,
                  onClear: () {
                    setState(() {
                      criteria.minPriority = null;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: (criteria.minPriority ?? 0).toDouble(),
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: criteria.minPriority != null
                            ? '≥ ${criteria.minPriority}'
                            : 'Off',
                        onChanged: (val) {
                          setState(() {
                            criteria.minPriority = val == 0 ? null : val.round();
                            widget.controller.updateHighlightCriteria();
                          });
                        },
                      ),
                    ),
                    Text(
                      criteria.minPriority != null ? '≥ ${criteria.minPriority}' : 'Any',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Assigned to person or set of persons
                _buildCriterionHeader(
                  title: 'Assigned Teammates',
                  color: HighlightCriteria.colorAssignees,
                  isActive: criteria.assigneeIds.isNotEmpty,
                  onClear: () {
                    setState(() {
                      criteria.assigneeIds.clear();
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                SearchableMultiSelectMenu<int>(
                  title: 'Assigned Teammates',
                  prefixIcon: Icons.people_outline,
                  hintText: teammates.isEmpty
                      ? 'No teammates added yet'
                      : 'Click to search and select teammates...',
                  selectedValues: criteria.assigneeIds,
                  items: teammates
                      .map((p) => SearchableItem<int>(
                            value: p.personId,
                            label: p.name,
                            subtitle: 'ID: ${p.personId}',
                            leading: CircleAvatar(
                              radius: 12,
                              child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                            ),
                          ))
                      .toList(),
                  onChanged: (newIds) {
                    setState(() {
                      criteria.assigneeIds.clear();
                      criteria.assigneeIds.addAll(newIds);
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 6. Dependencies completed
                _buildCriterionHeader(
                  title: 'Requisite Dependencies',
                  color: HighlightCriteria.colorDepsComplete,
                  isActive: criteria.dependenciesCompleted,
                  onClear: () {
                    setState(() {
                      criteria.dependenciesCompleted = false;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('All dependencies completed'),
                  value: criteria.dependenciesCompleted,
                  onChanged: (val) {
                    setState(() {
                      criteria.dependenciesCompleted = val;
                      widget.controller.updateHighlightCriteria();
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),

                // Color Legend (User story 17)
                Text(
                  'Color Legend (Separate Mode)',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildLegendItem('Due Before Specified', HighlightCriteria.colorDueBefore),
                _buildLegendItem('Milestone Member', HighlightCriteria.colorMilestone),
                _buildLegendItem('Incomplete Task', HighlightCriteria.colorIncomplete),
                _buildLegendItem('Priority ≥ Threshold', HighlightCriteria.colorPriority),
                _buildLegendItem('Assigned Teammate', HighlightCriteria.colorAssignees),
                _buildLegendItem('Dependencies Completed', HighlightCriteria.colorDepsComplete),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCriterionHeader({
    required String title,
    required Color color,
    required bool isActive,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const Spacer(),
        if (isActive)
          InkWell(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Clear',
                style: TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
