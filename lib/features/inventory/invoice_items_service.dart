import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';
import '../integration/workiz_service.dart';

/// Service for managing invoice/repair items
/// Used in inspection forms to select recommended repairs with pricing
class InvoiceItemsService {
  static String get _baseUrl => ApiConfig.apiBase;

  // Singleton pattern
  static final InvoiceItemsService _instance = InvoiceItemsService._internal();
  factory InvoiceItemsService() => _instance;
  InvoiceItemsService._internal();

  final ApiClient _api = ApiClient.instance;

  // Cache for items
  List<InvoiceItem> _cachedItems = [];
  List<ItemCategory> _cachedCategories = [];
  DateTime? _lastSync;

  /// Sync invoice items from Workiz
  /// Uses the location's credentials to fetch items from Workiz unofficial API
  Future<SyncResult> syncFromWorkiz({String? locationCode}) async {
    try {
      final body = <String, dynamic>{'action': 'sync'};
      if (locationCode != null) {
        body['location_code'] = locationCode;
      }

      final response = await _api.post(
        '$_baseUrl/invoice_items.php',
        body: body,
      );

      debugPrint('Invoice items sync response: ${response.rawJson}');

      if (response.success) {
        _lastSync = DateTime.now();
        _cachedItems = []; // Clear cache to force refresh
        final data = response.rawJson!;
        final synced = data['synced'] ?? 0;
        final totalFromWorkiz = data['total_from_workiz'] ?? 0;
        final updated = data['updated'] ?? 0;
        final location = data['location_used'] ?? '';

        String message;
        if (totalFromWorkiz == 0) {
          message = 'No items found in Workiz for $location';
        } else {
          message = 'Synced $synced new, $updated updated from $totalFromWorkiz items';
        }

        return SyncResult(
          success: true,
          syncedCount: synced + updated,
          message: message,
        );
      }
      return SyncResult(success: false, message: response.message ?? 'Sync failed');
    } catch (e) {
      debugPrint('Error syncing invoice items: $e');
      return SyncResult(success: false, message: e.toString());
    }
  }

  /// Get all invoice items
  Future<List<InvoiceItem>> getItems({
    String? category,
    bool includeInactive = false,
    bool forceRefresh = false,
  }) async {
    // Return cached if available
    if (!forceRefresh && _cachedItems.isNotEmpty && category == null) {
      return _cachedItems;
    }

    try {
      final queryParams = {
        'action': 'list',
        'include_inactive': includeInactive.toString(),
      };
      if (category != null) queryParams['category'] = category;

      final url = Uri.parse('$_baseUrl/invoice_items.php')
          .replace(queryParameters: queryParams)
          .toString();

      final response = await _api.get(url);

      if (response.success && response.rawJson?['items'] != null) {
        final items = (response.rawJson!['items'] as List)
            .map((i) => InvoiceItem.fromJson(i))
            .toList();

        if (category == null) {
          _cachedItems = items;
        }
        return items;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting invoice items: $e');
      return [];
    }
  }

  /// Search invoice items
  Future<List<InvoiceItem>> searchItems(String query) async {
    if (query.length < 2) return [];

    try {
      final url = '$_baseUrl/invoice_items.php?action=search&q=${Uri.encodeComponent(query)}';
      final response = await _api.get(url);

      if (response.success && response.rawJson?['items'] != null) {
        return (response.rawJson!['items'] as List)
            .map((i) => InvoiceItem.fromJson(i))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching invoice items: $e');
      return [];
    }
  }

  /// Get item categories
  Future<List<ItemCategory>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories.isNotEmpty) {
      return _cachedCategories;
    }

    try {
      final response = await _api.get('$_baseUrl/invoice_items.php?action=categories');

      if (response.success && response.rawJson?['categories'] != null) {
        _cachedCategories = (response.rawJson!['categories'] as List)
            .map((c) => ItemCategory.fromJson(c))
            .toList();
        return _cachedCategories;
      }
      return [];
    } catch (e) {
      debugPrint('Error getting item categories: $e');
      return [];
    }
  }

  /// Get single item by ID
  Future<InvoiceItem?> getItem(int id) async {
    try {
      final response = await _api.get('$_baseUrl/invoice_items.php?action=get&id=$id');

      if (response.success && response.rawJson?['item'] != null) {
        return InvoiceItem.fromJson(response.rawJson!['item']);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invoice item: $e');
      return null;
    }
  }

  /// Get multiple items by IDs
  Future<List<InvoiceItem>> getItemsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    try {
      final response = await _api.get(
        '$_baseUrl/invoice_items.php?action=bulk_get&ids=${ids.join(",")}',
      );

      if (response.success && response.rawJson?['items'] != null) {
        return (response.rawJson!['items'] as List)
            .map((i) => InvoiceItem.fromJson(i))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting invoice items by IDs: $e');
      return [];
    }
  }

  /// Create custom item (local only)
  Future<InvoiceItem?> createCustomItem({
    required String name,
    String? sku,
    String? description,
    String? category,
    required double price,
    double? cost,
    String? unit,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/invoice_items.php',
        body: {
          'action': 'create',
          'item_name': name,
          'sku': sku,
          'short_description': description,
          'category': category,
          'price': price,
          'cost': cost,
          'unit': unit ?? 'each',
        },
      );

      if (response.success && response.rawJson?['item_id'] != null) {
        _cachedItems = []; // Clear cache
        return await getItem(response.rawJson!['item_id']);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating custom item: $e');
      return null;
    }
  }

  /// Clear cached data
  void clearCache() {
    _cachedItems = [];
    _cachedCategories = [];
    _lastSync = null;
  }

  DateTime? get lastSync => _lastSync;
  bool get hasCachedItems => _cachedItems.isNotEmpty;
}

/// Item category model
class ItemCategory {
  final int id;
  final String name;
  final String? description;
  final int sortOrder;
  final int itemCount;

  ItemCategory({
    required this.id,
    required this.name,
    this.description,
    this.sortOrder = 0,
    this.itemCount = 0,
  });

  factory ItemCategory.fromJson(Map<String, dynamic> json) {
    return ItemCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      sortOrder: json['sort_order'] ?? 0,
      itemCount: json['item_count'] ?? 0,
    );
  }
}

/// Selected item in an inspection (with quantity)
class SelectedInvoiceItem {
  final InvoiceItem item;
  int quantity;
  String? notes;

  SelectedInvoiceItem({
    required this.item,
    this.quantity = 1,
    this.notes,
  });

  int get totalCents => item.priceCents * quantity;
  String get totalDisplay => '\$${(totalCents / 100).toStringAsFixed(2)}';

  Map<String, dynamic> toJson() {
    return {
      'id': item.id,
      'workiz_id': item.workizId,
      'item_name': item.name,
      'description': item.description,
      'price_cents': item.priceCents,
      'quantity': quantity,
      'notes': notes,
      'image_url': item.imageUrl,
    };
  }

  factory SelectedInvoiceItem.fromJson(Map<String, dynamic> json) {
    return SelectedInvoiceItem(
      item: InvoiceItem.fromJson(json),
      quantity: json['quantity'] ?? 1,
      notes: json['notes'],
    );
  }
}

/// Helper class to manage selected items in an inspection
class InvoiceItemsSelection {
  final List<SelectedInvoiceItem> _items = [];

  List<SelectedInvoiceItem> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalCents {
    return _items.fold(0, (sum, item) => sum + item.totalCents);
  }

  String get totalDisplay => '\$${(totalCents / 100).toStringAsFixed(2)}';

  void add(InvoiceItem item, {int quantity = 1, String? notes}) {
    // Check if already exists
    final existingIndex = _items.indexWhere((i) => i.item.id == item.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(SelectedInvoiceItem(
        item: item,
        quantity: quantity,
        notes: notes,
      ));
    }
  }

  void remove(int itemId) {
    _items.removeWhere((i) => i.item.id == itemId);
  }

  void updateQuantity(int itemId, int quantity) {
    final index = _items.indexWhere((i) => i.item.id == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
    }
  }

  void updateNotes(int itemId, String? notes) {
    final index = _items.indexWhere((i) => i.item.id == itemId);
    if (index >= 0) {
      _items[index].notes = notes;
    }
  }

  void clear() {
    _items.clear();
  }

  bool contains(int itemId) {
    return _items.any((i) => i.item.id == itemId);
  }

  SelectedInvoiceItem? get(int itemId) {
    try {
      return _items.firstWhere((i) => i.item.id == itemId);
    } catch (e) {
      debugPrint('[InvoiceItemsService] Error: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> toJson() {
    return _items.map((i) => i.toJson()).toList();
  }

  void loadFromJson(List<dynamic> jsonList) {
    _items.clear();
    for (final json in jsonList) {
      if (json is Map<String, dynamic>) {
        _items.add(SelectedInvoiceItem.fromJson(json));
      }
    }
  }
}
