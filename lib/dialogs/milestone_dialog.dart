import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../models/milestone.dart';
import '../models/schedule_date.dart';
import 'date_picker_dialog.dart';

class MilestoneDialog extends StatefulWidget {
  final ScheduleController controller;

  const MilestoneDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, ScheduleController controller) {
    return showDialog(
      context: context,
      builder: (ctx) => MilestoneDialog(controller: controller),
    );
  }

  @override
  State<MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<MilestoneDialog> {
  final _nameController = TextEditingController();
  ScheduleDate? _newDeadline;

  void _addMilestone() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.controller.addMilestone(name, _newDeadline);
    _nameController.clear();
    setState(() {
      _newDeadline = null;
    });
  }

  void _editMilestone(Milestone milestone) {
    final editController = TextEditingController(text: milestone.name);
    ScheduleDate? editDeadline = milestone.deadline;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Milestone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editController,
                decoration: const InputDecoration(
                  labelText: 'Milestone Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text(
                  editDeadline != null
                      ? 'Deadline: ${editDeadline!.formatted}'
                      : 'No Deadline Assigned',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (editDeadline != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setDialogState(() {
                            editDeadline = null;
                          });
                        },
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(editDeadline == null ? 'Set' : 'Change'),
                      onPressed: () async {
                        final picked = await ScheduleDatePickerDialog.show(
                          context,
                          initialDate: editDeadline,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            editDeadline = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newName = editController.text.trim();
                if (newName.isNotEmpty) {
                  widget.controller.updateMilestone(
                    milestone.copyWith(
                      name: newName,
                      deadline: editDeadline,
                      clearDeadline: editDeadline == null,
                    ),
                  );
                  Navigator.of(ctx).pop();
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final milestones = widget.controller.schedule.milestones;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 480;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 16),
      title: const Row(
        children: [
          Icon(Icons.flag_rounded),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Manage Milestones',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (isMobile) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'New Milestone Name',
                  hintText: 'e.g. Beta Release',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _addMilestone(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await ScheduleDatePickerDialog.show(
                          context,
                          initialDate: _newDeadline,
                        );
                        if (picked != null) {
                          setState(() => _newDeadline = picked);
                        }
                      },
                      icon: Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: _newDeadline != null ? theme.colorScheme.primary : null,
                      ),
                      label: Text(
                        _newDeadline != null ? _newDeadline!.formatted : 'Deadline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _newDeadline != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addMilestone,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'New Milestone Name',
                        hintText: 'e.g. Beta Release',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _addMilestone(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ScheduleDatePickerDialog.show(
                        context,
                        initialDate: _newDeadline,
                      );
                      if (picked != null) {
                        setState(() => _newDeadline = picked);
                      }
                    },
                    icon: Icon(
                      Icons.calendar_month,
                      size: 18,
                      color: _newDeadline != null ? theme.colorScheme.primary : null,
                    ),
                    label: Text(
                      _newDeadline != null ? _newDeadline!.formatted : 'Deadline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _newDeadline != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addMilestone,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'Milestones (${milestones.length})',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: milestones.isEmpty
                  ? Center(
                      child: Text(
                        'No milestones added yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: milestones.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final ms = milestones[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            child: Icon(
                              Icons.flag,
                              size: 14,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                          title: Text(
                            ms.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            ms.deadline != null
                                ? 'Due: ${ms.deadline!.formatted}'
                                : 'No deadline',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ms.deadline != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit Milestone',
                                onPressed: () => _editMilestone(ms),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: theme.colorScheme.error),
                                tooltip: 'Delete Milestone',
                                onPressed: () {
                                  widget.controller.deleteMilestone(ms.milestoneId);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
