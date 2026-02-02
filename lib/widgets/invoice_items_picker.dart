import 'package:flutter/material.dart';
import '../features/inventory/invoice_items_service.dart';
import '../features/integration/workiz_service.dart';

/// Widget for selecting invoice/repair items in an inspection
class InvoiceItemsPicker extends StatefulWidget {
  final InvoiceItemsSelection selection;
  final Function(InvoiceItemsSelection) onSelectionChanged;
  final String? sectionLabel; // e.g., "Chimney Repairs", "Firebox Issues"
  final String? locationCode; // Workiz location code for syncing items

  const InvoiceItemsPicker({
    super.key,
    required this.selection,
    required this.onSelectionChanged,
    this.sectionLabel,
    this.locationCode,
  });

  @override
  State<InvoiceItemsPicker> createState() => _InvoiceItemsPickerState();
}

class _InvoiceItemsPickerState extends State<InvoiceItemsPicker> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.receipt_long, size: 20, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              widget.sectionLabel ?? 'Recommended Services',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showItemPicker(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
            ),
          ],
        ),

        // Selected items list
        if (widget.selection.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...widget.selection.items.map((item) => _buildSelectedItem(item)),
          const Divider(),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimate Total:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.selection.totalDisplay,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No items selected. Tap "Add Item" to add recommended services.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedItem(SelectedInvoiceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.item.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.item.priceDisplay} x ${item.quantity} = ${item.totalDisplay}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (item.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () {
                  if (item.quantity > 1) {
                    widget.selection.updateQuantity(item.item.id!, item.quantity - 1);
                    widget.onSelectionChanged(widget.selection);
                    setState(() {});
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () {
                  widget.selection.updateQuantity(item.item.id!, item.quantity + 1);
                  widget.onSelectionChanged(widget.selection);
                  setState(() {});
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                onPressed: () {
                  widget.selection.remove(item.item.id!);
                  widget.onSelectionChanged(widget.selection);
                  setState(() {});
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showItemPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ItemPickerSheet(
          scrollController: scrollController,
          selection: widget.selection,
          locationCode: widget.locationCode,
          onItemSelected: (item) {
            widget.selection.add(item);
            widget.onSelectionChanged(widget.selection);
            setState(() {});
          },
        ),
      ),
    );
  }
}

/// Bottom sheet for picking items
class _ItemPickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final InvoiceItemsSelection selection;
  final Function(InvoiceItem) onItemSelected;
  final String? locationCode;

  const _ItemPickerSheet({
    required this.scrollController,
    required this.selection,
    required this.onItemSelected,
    this.locationCode,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final InvoiceItemsService _service = InvoiceItemsService();
  final TextEditingController _searchController = TextEditingController();

  List<InvoiceItem> _items = [];
  List<ItemCategory> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.getItems(),
        _service.getCategories(),
      ]);
      _items = results[0] as List<InvoiceItem>;
      _categories = results[1] as List<ItemCategory>;

      // If no items found and we haven't synced yet, try auto-sync
      if (_items.isEmpty && !_service.hasCachedItems) {
        debugPrint('No invoice items found, attempting auto-sync from Workiz...');
        final syncResult = await _service.syncFromWorkiz(locationCode: widget.locationCode);
        if (syncResult.success && (syncResult.syncedCount) > 0) {
          debugPrint('Auto-synced ${syncResult.syncedCount} items, reloading...');
          // Reload items after sync
          _items = await _service.getItems(forceRefresh: true);
          _categories = await _service.getCategories(forceRefresh: true);
        } else {
          debugPrint('Sync result: ${syncResult.message}');
        }
      }
    } catch (e) {
      debugPrint('Error loading items: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      await _loadData();
      return;
    }

    setState(() => _isLoading = true);
    try {
      _items = await _service.searchItems(query);
    } catch (e) {
      debugPrint('Error searching: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _filterByCategory(String? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    try {
      _items = await _service.getItems(category: category);
    } catch (e) {
      debugPrint('Error filtering: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Add Service Item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: _search,
          ),
        ),

        // Categories filter
        if (_categories.isNotEmpty && _searchController.text.length < 2)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip(null, 'All'),
                ..._categories.map((c) => _buildCategoryChip(c.name, c.name)),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Items list
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading items...',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No items match your search'
                                  : 'No service items available',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try a different search term'
                                  : 'Items need to be synced from Workiz first.\nTap the button below to import your service catalog.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            if (_searchController.text.isEmpty)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setState(() => _isLoading = true);
                                  final result = await _service.syncFromWorkiz(locationCode: widget.locationCode);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.success ? result.message : 'Sync failed: ${result.message}'),
                                        backgroundColor: result.success && result.syncedCount > 0 ? Colors.green : (result.success ? Colors.orange : Colors.red),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                  await _loadData();
                                },
                                icon: const Icon(Icons.sync),
                                label: const Text('Sync from Workiz'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final isSelected = widget.selection.contains(item.id!);

                        return ListTile(
                          leading: item.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    item.imageUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade200,
                                      child: Icon(Icons.image, color: Colors.grey.shade400),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(Icons.handyman, color: Colors.grey.shade500),
                                ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: item.description != null
                              ? Text(
                                  item.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.priceDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Colors.blue)
                              else
                                const Icon(Icons.add_circle_outline),
                            ],
                          ),
                          onTap: () {
                            widget.onItemSelected(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final isSelected = _selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _filterByCategory(value),
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue.shade100,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue.shade900 : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Compact summary of selected items (for review screens)
class InvoiceItemsSummary extends StatelessWidget {
  final InvoiceItemsSelection selection;
  final bool showDetails;

  const InvoiceItemsSummary({
    super.key,
    required this.selection,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    if (selection.isEmpty) {
      return Text(
        'No services selected',
        style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDetails)
          ...selection.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.item.name} x${item.quantity}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      item.totalDisplay,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              )),
        if (showDetails) const Divider(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total (${selection.count} items):',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              selection.totalDisplay,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
