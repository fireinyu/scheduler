import 'package:flutter/material.dart';
import '../utils/fuzzy_search.dart';

/// A selectable item in a searchable menu.
class SearchableItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool isNoneOption;

  const SearchableItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.isNoneOption = false,
  });
}

/// A dropdown menu for single-item selection with an integrated search-by-name field
/// that dynamically updates to show the closest matches (User Story 20).
class SearchableDropdown<T> extends StatelessWidget {
  final String labelText;
  final String? hintText;
  final String? helperText;
  final IconData? prefixIcon;
  final T value;
  final List<SearchableItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool isDense;

  const SearchableDropdown({
    super.key,
    required this.labelText,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.isDense = false,
  });

  SearchableItem<T>? get _selectedItem {
    try {
      return items.firstWhere((it) => it.value == value);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedItem;
    final displayText = selected?.label ?? hintText ?? 'Select $labelText...';

    return InkWell(
      onTap: () async {
        final chosen = await SearchableMenuDialog.show<T>(
          context: context,
          title: 'Select $labelText',
          initialValue: value,
          items: items,
        );
        if (chosen != null || (items.any((it) => it.value == null && chosen == null))) {
          onChanged(chosen as T);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: isDense,
          labelText: labelText,
          helperText: helperText,
          border: const OutlineInputBorder(),
          contentPadding: isDense
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
          suffixIcon: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 18, color: Colors.grey),
              SizedBox(width: 2),
              Icon(Icons.arrow_drop_down),
              SizedBox(width: 6),
            ],
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: selected == null ? theme.hintColor : theme.textTheme.bodyMedium?.color,
            fontSize: isDense ? 13 : 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Dialog menu containing search field and list of closest matches (User Story 20)
class SearchableMenuDialog<T> extends StatefulWidget {
  final String title;
  final T? initialValue;
  final List<SearchableItem<T>> items;

  const SearchableMenuDialog({
    super.key,
    required this.title,
    this.initialValue,
    required this.items,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    T? initialValue,
    required List<SearchableItem<T>> items,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SearchableMenuDialog<T>(
        title: title,
        initialValue: initialValue,
        items: items,
      ),
    );
  }

  @override
  State<SearchableMenuDialog<T>> createState() => _SearchableMenuDialogState<T>();
}

class _SearchableMenuDialogState<T> extends State<SearchableMenuDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter and rank items so the closest matches appear first
    final filteredItems = FuzzySearch.filterAndRank<SearchableItem<T>>(
      items: widget.items,
      getName: (it) => it.label,
      query: _query,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with title and close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search by name input inside the same menu (User Story 20)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),

            // Result feedback: Closest matches
            if (_query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Showing closest matches (${filteredItems.length})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 12),

            // Scrollable list of closest matching items
            Flexible(
              child: filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No matching items found for "$_query"',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      shrinkWrap: true,
                      itemBuilder: (ctx, index) {
                        final item = filteredItems[index];
                        final isSelected = item.value == widget.initialValue;

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          leading: item.leading ??
                              (isSelected
                                  ? Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary)
                                  : const Icon(Icons.radio_button_unchecked, size: 20, color: Colors.grey)),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                          onTap: () => Navigator.of(context).pop(item.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A multi-select menu with an integrated search-by-name field that dynamically updates
/// to show the closest matches (User Story 20).
class SearchableMultiSelectMenu<T> extends StatelessWidget {
  final String title;
  final String? hintText;
  final IconData? prefixIcon;
  final Set<T> selectedValues;
  final List<SearchableItem<T>> items;
  final ValueChanged<Set<T>> onChanged;
  final String? emptyPlaceholder;

  const SearchableMultiSelectMenu({
    super.key,
    required this.title,
    required this.selectedValues,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.prefixIcon,
    this.emptyPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItems = items.where((it) => selectedValues.contains(it.value)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Menu trigger button
        InkWell(
          onTap: () async {
            final updated = await showDialog<Set<T>>(
              context: context,
              builder: (ctx) => _SearchableMultiMenuDialog<T>(
                title: title,
                initialSelected: Set<T>.from(selectedValues),
                items: items,
              ),
            );
            if (updated != null) {
              onChanged(updated);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
              suffixIcon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 18, color: Colors.grey),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down),
                  SizedBox(width: 6),
                ],
              ),
            ),
            child: Text(
              selectedItems.isEmpty
                  ? (hintText ?? 'Click to select or search $title...')
                  : '${selectedItems.length} selected',
              style: TextStyle(
                color: selectedItems.isEmpty ? theme.hintColor : theme.textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Selected chips preview
        if (selectedItems.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedItems.map((item) {
              return Chip(
                avatar: item.leading,
                label: Text(item.label, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  final next = Set<T>.from(selectedValues)..remove(item.value);
                  onChanged(next);
                },
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _SearchableMultiMenuDialog<T> extends StatefulWidget {
  final String title;
  final Set<T> initialSelected;
  final List<SearchableItem<T>> items;

  const _SearchableMultiMenuDialog({
    required this.title,
    required this.initialSelected,
    required this.items,
  });

  @override
  State<_SearchableMultiMenuDialog<T>> createState() => _SearchableMultiMenuDialogState<T>();
}

class _SearchableMultiMenuDialogState<T> extends State<_SearchableMultiMenuDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  late Set<T> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter and rank items so closest matches appear first (User Story 20)
    final filteredItems = FuzzySearch.filterAndRank<SearchableItem<T>>(
      items: widget.items,
      getName: (it) => it.label,
      query: _query,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with title, count, and close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title} (${_selected.length} selected)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(_selected),
                  ),
                ],
              ),
            ),

            // Search by name input inside the same menu (User Story 20)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),

            // Selection controls and match feedback
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _query.trim().isNotEmpty
                        ? Text(
                            'Closest matches (${filteredItems.length})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        for (final item in filteredItems) {
                          _selected.add(item.value);
                        }
                      });
                    },
                    child: const Text('Select All', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        for (final item in filteredItems) {
                          _selected.remove(item.value);
                        }
                      });
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            const Divider(height: 8),

            // Scrollable list of closest matching items with checkboxes
            Flexible(
              child: filteredItems.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No matching items found for "$_query"',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      shrinkWrap: true,
                      itemBuilder: (ctx, index) {
                        final item = filteredItems[index];
                        final isChecked = _selected.contains(item.value);

                        return CheckboxListTile(
                          dense: true,
                          value: isChecked,
                          secondary: item.leading,
                          title: Text(item.label),
                          subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                          onChanged: (bool? val) {
                            setState(() {
                              if (val == true) {
                                _selected.add(item.value);
                              } else {
                                _selected.remove(item.value);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // Footer action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
