import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders a task's note as obsidian-flavoured markdown.
///
/// User story 4:
/// - each note is rendered as obsidian-flavoured markdown
/// - In any view of the tasks, only the first line of the note is visible by default
class ObsidianMarkdownView extends StatefulWidget {
  final String? note;
  final bool initialExpanded;
  final bool allowToggle;

  const ObsidianMarkdownView({
    super.key,
    required this.note,
    this.initialExpanded = false,
    this.allowToggle = true,
  });

  @override
  State<ObsidianMarkdownView> createState() => _ObsidianMarkdownViewState();
}

class _ObsidianMarkdownViewState extends State<ObsidianMarkdownView> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.note == null || widget.note!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final firstLine = _getFirstLine(widget.note!);

    if (!_isExpanded) {
      // Compact: Only the first line is visible by default
      return InkWell(
        onTap: widget.allowToggle
            ? () {
                setState(() {
                  _isExpanded = true;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sticky_note_2_outlined,
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  firstLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.allowToggle) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Expanded: Rendered as obsidian-flavoured markdown
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.notes,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Markdown Note',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.allowToggle)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Collapse',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Icon(
                        Icons.expand_less,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 12),
          MarkdownBody(
            data: widget.note!,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium,
              code: TextStyle(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFirstLine(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      }
    }
    return '';
  }
}
