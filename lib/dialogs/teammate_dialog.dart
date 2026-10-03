import 'package:flutter/material.dart';
import '../controllers/schedule_controller.dart';
import '../models/person.dart';

class TeammateDialog extends StatefulWidget {
  final ScheduleController controller;

  const TeammateDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, ScheduleController controller) {
    return showDialog(
      context: context,
      builder: (ctx) => TeammateDialog(controller: controller),
    );
  }

  @override
  State<TeammateDialog> createState() => _TeammateDialogState();
}

class _TeammateDialogState extends State<TeammateDialog> {
  final _nameController = TextEditingController();

  void _addTeammate() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.controller.addTeammate(name);
    _nameController.clear();
    setState(() {});
  }

  void _editTeammate(Person person) {
    final editController = TextEditingController(text: person.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Teammate'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
                widget.controller.updateTeammate(person.copyWith(name: newName));
                Navigator.of(ctx).pop();
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
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
    final teammates = widget.controller.schedule.teammates;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.people_alt_outlined),
          SizedBox(width: 8),
          Text('Manage Teammates'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'New Teammate Name',
                      hintText: 'e.g. Alice Smith',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _addTeammate(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addTeammate,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Team Members (${teammates.length})',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: teammates.isEmpty
                  ? Center(
                      child: Text(
                        'No teammates added yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: teammates.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final person = teammates[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text('ID: ${person.personId}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Edit Name',
                                onPressed: () => _editTeammate(person),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: theme.colorScheme.error),
                                tooltip: 'Delete Teammate',
                                onPressed: () {
                                  widget.controller.deleteTeammate(person.personId);
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
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
