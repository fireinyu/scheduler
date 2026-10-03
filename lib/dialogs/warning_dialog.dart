import 'package:flutter/material.dart';

/// Clean warning confirmation dialog for User stories 10, 11, and 13.
class WarningDialog extends StatelessWidget {
  final String title;
  final List<String> warnings;
  final String proceedLabel;
  final String cancelLabel;
  final Color? proceedColor;
  final IconData icon;

  const WarningDialog({
    super.key,
    required this.title,
    required this.warnings,
    this.proceedLabel = 'Proceed Anyway',
    this.cancelLabel = 'Cancel',
    this.proceedColor,
    this.icon = Icons.warning_amber_rounded,
  });

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required List<String> warnings,
    String proceedLabel = 'Proceed Anyway',
    String cancelLabel = 'Cancel',
    Color? proceedColor,
    IconData icon = Icons.warning_amber_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => WarningDialog(
        title: title,
        warnings: warnings,
        proceedLabel: proceedLabel,
        cancelLabel: cancelLabel,
        proceedColor: proceedColor,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = proceedColor ?? theme.colorScheme.error;

    return AlertDialog(
      icon: Icon(icon, color: accentColor, size: 36),
      title: Text(title, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please review the following warnings before proceeding:',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                w,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(proceedLabel),
        ),
      ],
    );
  }
}
