// Searchable List Widget
//
// A reusable searchable/filterable list component with built-in
// search bar, filtering, and export capabilities.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../utils/csv_exporter.dart';

/// Configuration for searchable list
class SearchableListConfig<T> {
  /// Function to extract searchable text from an item
  final String Function(T item) searchTextExtractor;

  /// Optional function to get item's category for filtering
  final String? Function(T item)? categoryExtractor;

  /// Available categories for filter dropdown
  final List<String>? categories;

  /// Placeholder text for search field
  final String searchHint;

  /// Whether to show export button
  final bool showExport;

  /// CSV export configuration (required if showExport is true)
  final CsvExportConfig? exportConfig;

  /// Empty state message
  final String emptyMessage;

  /// No results message
  final String noResultsMessage;

  const SearchableListConfig({
    required this.searchTextExtractor,
    this.categoryExtractor,
    this.categories,
    this.searchHint = 'Search...',
    this.showExport = false,
    this.exportConfig,
    this.emptyMessage = 'No items found',
    this.noResultsMessage = 'No results match your search',
  });
}

/// A searchable, filterable list with export capability
class SearchableList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final SearchableListConfig<T> config;
  final bool isLoading;
  final Widget? loadingWidget;
  final EdgeInsets? padding;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? header;
  final Widget? emptyWidget;

  const SearchableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.config,
    this.isLoading = false,
    this.loadingWidget,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.header,
    this.emptyWidget,
  });

  @override
  State<SearchableList<T>> createState() => _SearchableListState<T>();
}

class _SearchableListState<T> extends State<SearchableList<T>> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    var items = widget.items;

    // Filter by category
    if (_selectedCategory != null && widget.config.categoryExtractor != null) {
      items = items.where((item) {
        final category = widget.config.categoryExtractor!(item);
        return category == _selectedCategory;
      }).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      items = items.where((item) {
        final searchText = widget.config.searchTextExtractor(item).toLowerCase();
        return searchText.contains(query);
      }).toList();
    }

    return items;
  }

  Future<void> _handleExport() async {
    if (widget.config.exportConfig == null) return;

    final result = await CsvExporter.export(
      data: _filteredItems,
      config: widget.config.exportConfig!,
      context: context,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Exported ${result.rowCount} items'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result.error != 'Export cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Export failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredItems = _filteredItems;

    return Column(
      children: [
        // Search bar and filters
        _buildSearchBar(isDark),

        // Header if provided
        if (widget.header != null) widget.header!,

        // Content
        Expanded(
          child: widget.isLoading
              ? widget.loadingWidget ?? const Center(child: CircularProgressIndicator())
              : widget.items.isEmpty
                  ? _buildEmptyState(isDark, isFiltered: false)
                  : filteredItems.isEmpty
                      ? _buildEmptyState(isDark, isFiltered: true)
                      : ListView.builder(
                          controller: widget.scrollController,
                          padding: widget.padding,
                          shrinkWrap: widget.shrinkWrap,
                          physics: widget.physics,
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return widget.itemBuilder(
                              context,
                              filteredItems[index],
                              index,
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: widget.config.searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                ),
              ),
            ),
          ),

          // Category filter
          if (widget.config.categories != null && widget.config.categories!.isNotEmpty) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              height: 40,
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                ),
                hint: const Text('All'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ...widget.config.categories!.map(
                    (cat) => DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
            ),
          ],

          // Export button
          if (widget.config.showExport && widget.config.exportConfig != null) ...[
            const SizedBox(width: 12),
            Tooltip(
              message: 'Export to CSV',
              child: IconButton(
                icon: const Icon(Icons.download),
                onPressed: _filteredItems.isEmpty ? null : _handleExport,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  foregroundColor: AppColors.accent,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1),
                  disabledForegroundColor: Colors.grey,
                ),
              ),
            ),
          ],

          // Results count
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_filteredItems.length} item${_filteredItems.length != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {required bool isFiltered}) {
    if (widget.emptyWidget != null && !isFiltered) {
      return widget.emptyWidget!;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.search_off : Icons.inbox_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? widget.config.noResultsMessage
                : widget.config.emptyMessage,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = null;
                });
              },
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A simple search bar widget that can be added to any screen
class SearchBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final bool autofocus;
  final double? width;

  const SearchBar({
    super.key,
    this.hint = 'Search...',
    required this.onChanged,
    this.onClear,
    this.controller,
    this.autofocus = false,
    this.width,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_updateHasText);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_updateHasText);
    }
    super.dispose();
  }

  void _updateHasText() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: widget.width,
      height: 40,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _hasText
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _clear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
        ),
      ),
    );
  }
}
