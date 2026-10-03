import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../controllers/schedule_controller.dart';
import '../services/schedule_validator.dart';

class ImportExportDialog extends StatefulWidget {
  final ScheduleController controller;

  const ImportExportDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, ScheduleController controller) {
    return showDialog(
      context: context,
      builder: (ctx) => ImportExportDialog(controller: controller),
    );
  }

  @override
  State<ImportExportDialog> createState() => _ImportExportDialogState();
}

class _ImportExportDialogState extends State<ImportExportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _importJsonController = TextEditingController();
  String? _importError;
  bool _importSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importJsonController.dispose();
    super.dispose();
  }

  Future<void> _exportToFile() async {
    try {
      final jsonStr = widget.controller.exportJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export Schedule (schedule.json format)',
        fileName: 'schedule.json',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (uri != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully exported to ${uri.path}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isNotEmpty) {
        final platformFile = result.first;
        final bytes = await platformFile.readAsBytes();
        final content = utf8.decode(bytes);

        _importJsonController.text = content;
        _doImport(content);
      }
    } catch (e) {
      setState(() {
        _importError = 'Failed to read file: $e';
        _importSuccess = false;
      });
    }
  }

  void _doImport(String text) {
    setState(() {
      _importError = null;
      _importSuccess = false;
    });

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _importError = 'JSON content cannot be empty.');
      return;
    }

    try {
      final decoded = jsonDecode(trimmed);
      final errors = ScheduleValidator.validate(decoded);
      if (errors.isNotEmpty) {
        setState(() {
          _importError = 'JSON does not conform to schedule.json schema:\n• ${errors.join('\n• ')}';
        });
        return;
      }

      widget.controller.importJson(trimmed);
      setState(() {
        _importSuccess = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule imported and saved successfully!')),
      );
    } catch (e) {
      setState(() {
        _importError = 'Invalid JSON: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentExportJson = widget.controller.exportJson();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 520;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Import / Export Schedule',
                            style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.file_upload_outlined), text: 'Export'),
                  Tab(icon: Icon(Icons.file_download_outlined), text: 'Import'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Export Tab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Conforms to schedule.json schema',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                tooltip: 'Copy JSON to clipboard',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: currentExportJson));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied JSON to clipboard!')),
                                  );
                                },
                              ),
                              FilledButton.icon(
                                onPressed: _exportToFile,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Export to File'),
                              ),
                            ],
                          ),
                        ] else
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Conforms strictly to schedule.json schema',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                tooltip: 'Copy JSON to clipboard',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: currentExportJson));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied JSON to clipboard!')),
                                  );
                                },
                              ),
                              FilledButton.icon(
                                onPressed: _exportToFile,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Export to File'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                currentExportJson,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Import Tab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Paste JSON or pick file:',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _importFromFile,
                                icon: const Icon(Icons.folder_open, size: 18),
                                label: const Text('Choose File'),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Text(
                                'Paste schedule JSON or pick file from disk:',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: _importFromFile,
                                icon: const Icon(Icons.folder_open, size: 18),
                                label: const Text('Choose File'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TextField(
                            controller: _importJsonController,
                            maxLines: null,
                            expands: true,
                            decoration: const InputDecoration(
                              hintText: 'Paste valid schedule.json content here...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        if (_importError != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _importError!,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        if (_importSuccess) ...[
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Import successfully validated and saved to disk!',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _doImport(_importJsonController.text),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Validate & Import'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
