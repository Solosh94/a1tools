// Inspection List Screen
//
// Main entry screen for the inspection system with tabs for
// creating new inspections and viewing past inspections.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../app_theme.dart';
import 'inspection_models.dart';
import 'inspection_service.dart';
import 'inspection_report_service.dart';
import 'inspection_report_form.dart';
import 'inspection_detail_screen.dart';
import 'inspection_report_detail_screen.dart';

class InspectionListScreen extends StatefulWidget {
  final String username;
  final String firstName;
  final String lastName;
  final String role;

  const InspectionListScreen({
    super.key,
    required this.username,
    this.firstName = '',
    this.lastName = '',
    required this.role,
  });

  @override
  State<InspectionListScreen> createState() => _InspectionListScreenState();
}

class _InspectionListScreenState extends State<InspectionListScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;

  late TabController _tabController;
  List<Inspection> _inspections = [];
  List<InspectionReportSummary> _reports = []; // Comprehensive reports
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  // Filters
  String? _filterCategory;
  String? _filterStatus;
  String? _filterCondition;
  String? _filterTechnician;
  String? _filterCustomer;

  // Available filter options (loaded from API)
  List<TechnicianInfo> _technicians = [];
  List<String> _customers = [];

  // Workiz locations for the user
  List<Map<String, dynamic>> _userWorkizLocations = [];
  bool _loadingLocations = true;

  final _searchController = TextEditingController();

  bool get _isAdmin =>
      widget.role == 'developer' ||
      widget.role == 'administrator' ||
      widget.role == 'management';

  // Dispatchers can only view, not create inspections
  bool get _isDispatcher => widget.role == 'dispatcher' || widget.role == 'remote_dispatcher';

  // Can create inspections if: not a dispatcher AND has at least one Workiz location
  bool get _canCreateInspections => !_isDispatcher && _userWorkizLocations.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInspections();
    _loadUserWorkizLocations();
    if (_isAdmin) {
      _loadFilterOptions();
    }
  }

  Future<void> _loadUserWorkizLocations() async {
    setState(() => _loadingLocations = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.workizLocations}?action=user_locations&username=${widget.username}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _userWorkizLocations = List<Map<String, dynamic>>.from(data['locations'] ?? []);
            _loadingLocations = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Failed to load Workiz locations: $e');
    }

    setState(() => _loadingLocations = false);
  }

  Future<void> _loadFilterOptions() async {
    try {
      final technicians = await InspectionService.instance.getTechniciansWithInspections();
      final customers = await InspectionService.instance.getCustomersWithInspections();
      if (mounted) {
        setState(() {
          _technicians = technicians;
          _customers = customers;
        });
      }
    } catch (e) {
      // Silent fail
      debugPrint('[InspectionListScreen] Error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load both quick inspections and comprehensive reports
      List<Inspection> inspections;
      List<InspectionReportSummary> reports;

      if (_isAdmin) {
        // Load quick inspections
        inspections = await InspectionService.instance.getAllInspections(
          filterCategory: _filterCategory,
          filterCondition: _filterCondition,
          filterStatus: _filterStatus,
          filterTechnician: _filterTechnician,
          filterCustomer: _filterCustomer,
        );
        // Load comprehensive reports (all for admin)
        reports = await InspectionReportService.instance.getAllReports();
      } else {
        // Load quick inspections for this user
        inspections = await InspectionService.instance.getInspections(
          username: widget.username,
        );
        // Load comprehensive reports for this user
        reports = await InspectionReportService.instance.getReports(
          username: widget.username,
        );
      }

      if (mounted) {
        setState(() {
          _inspections = inspections;
          _reports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load inspections: $e';
          _loading = false;
        });
      }
    }
  }

  List<Inspection> get _filteredInspections {
    if (_searchQuery.isEmpty) return _inspections;

    final query = _searchQuery.toLowerCase();
    return _inspections.where((i) {
      return i.address.toLowerCase().contains(query) ||
          (i.customerName?.toLowerCase().contains(query) ?? false) ||
          i.chimneyType.toLowerCase().contains(query) ||
          i.jobCategory.toLowerCase().contains(query) ||
          i.jobType.toLowerCase().contains(query) ||
          i.displayName.toLowerCase().contains(query) ||
          i.issues.toLowerCase().contains(query);
    }).toList();
  }

  List<InspectionReportSummary> get _filteredReports {
    if (_searchQuery.isEmpty) return _reports;

    final query = _searchQuery.toLowerCase();
    return _reports.where((r) {
      return r.clientName.toLowerCase().contains(query) ||
          r.fullAddress.toLowerCase().contains(query) ||
          r.systemType.toLowerCase().contains(query) ||
          r.inspectorName.toLowerCase().contains(query);
    }).toList();
  }

  void _openNewInspection() {
    if (!_canCreateInspections) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDispatcher
              ? 'Dispatchers cannot create inspections'
              : 'No Workiz locations assigned. Contact an admin to get access.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If user has multiple locations, show selector
    if (_userWorkizLocations.length > 1) {
      _showLocationSelector();
    } else {
      // Single location - use it directly
      _navigateToInspectionForm(_userWorkizLocations.first);
    }
  }

  void _showLocationSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Which location is this inspection for?',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            // Location buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _userWorkizLocations.map((location) {
                  return SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToInspectionForm(location);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.location_on, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            location['location_name'] ?? location['location_code'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            location['location_code'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateToInspectionForm(Map<String, dynamic> location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionReportForm(
          username: widget.username,
          firstName: widget.firstName,
          lastName: widget.lastName,
          role: widget.role,
          workizLocationId: location['id'],
          workizLocationCode: location['location_code'],
          workizLocationName: location['location_name'],
          onInspectionCreated: () {
            _loadInspections();
            _tabController.animateTo(1);
          },
        ),
      ),
    );
  }

  void _openInspectionDetail(Inspection inspection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          inspection: inspection,
          isAdmin: _isAdmin,
          onDeleted: _loadInspections,
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filterCategory = null;
      _filterStatus = null;
      _filterCondition = null;
      _filterTechnician = null;
      _filterCustomer = null;
    });
    _loadInspections();
  }

  bool get _hasFilters =>
      _filterCategory != null ||
      _filterStatus != null ||
      _filterCondition != null ||
      _filterTechnician != null ||
      _filterCustomer != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Inspections'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle_outline),
              text: 'New',
            ),
            Tab(
              icon: Icon(Icons.list_alt),
              text: 'History',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // New Inspection Tab
          _buildNewInspectionTab(isDark),
          // History Tab
          _buildHistoryTab(isDark),
        ],
      ),
    );
  }

  Widget _buildNewInspectionTab(bool isDark) {
    // Loading state
    if (_loadingLocations) {
      return const Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }

    // Dispatcher - view only
    if (_isDispatcher) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'View Only Access',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dispatchers can view inspection history but cannot create new inspections.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.history),
                label: const Text('View History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No Workiz locations assigned
    if (_userWorkizLocations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.orange.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Location Assigned',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to be assigned to a Workiz location to create inspections.\n\nPlease contact an administrator to get access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _loadUserWorkizLocations,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Can create inspections - show location info
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_add,
                size: 64,
                color: _accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create New Inspection',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document chimney conditions with photos and detailed notes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            // Show available locations
            if (_userWorkizLocations.length == 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      _userWorkizLocations.first['location_name'] ?? _userWorkizLocations.first['location_code'] ?? 'Location',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      '${_userWorkizLocations.length} locations available',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 50,
              child: FilledButton.icon(
                onPressed: _openNewInspection,
                icon: const Icon(Icons.add),
                label: Text(_userWorkizLocations.length > 1 ? 'Select Location' : 'Start Inspection'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search inspections...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                        fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter button
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _hasFilters,
                      backgroundColor: _accent,
                      child: Icon(
                        Icons.filter_list,
                        color: _hasFilters
                            ? _accent
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                    onPressed: () => _showFilterSheet(isDark),
                  ),
                ],
              ),
              // Active filters display
              if (_hasFilters) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_filterCategory != null)
                        _buildFilterChip(_filterCategory!, () {
                          setState(() => _filterCategory = null);
                          _loadInspections();
                        }),
                      if (_filterStatus != null)
                        _buildFilterChip(
                          CompletionStatus.getDisplay(_filterStatus!),
                          () {
                            setState(() => _filterStatus = null);
                            _loadInspections();
                          },
                        ),
                      if (_filterCondition != null)
                        _buildFilterChip(_filterCondition!, () {
                          setState(() => _filterCondition = null);
                          _loadInspections();
                        }),
                      if (_filterTechnician != null)
                        _buildFilterChip(
                          'Tech: ${_technicians.firstWhere((t) => t.username == _filterTechnician, orElse: () => TechnicianInfo(username: _filterTechnician!, firstName: '', lastName: '', inspectionCount: 0)).displayName}',
                          () {
                            setState(() => _filterTechnician = null);
                            _loadInspections();
                          },
                        ),
                      if (_filterCustomer != null)
                        _buildFilterChip('Customer: $_filterCustomer', () {
                          setState(() => _filterCustomer = null);
                          _loadInspections();
                        }),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear all'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _accent),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadInspections,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                            ),
                          ),
                        ],
                      ),
                    )
                  : (_filteredReports.isEmpty && _filteredInspections.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _hasFilters
                                    ? 'No inspections match your search'
                                    : 'No inspections yet',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              if (_searchQuery.isEmpty && !_hasFilters) ...[
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: () => _tabController.animateTo(0),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create your first inspection'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadInspections,
                          color: _accent,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredReports.length + _filteredInspections.length,
                            itemBuilder: (context, index) {
                              // Show comprehensive reports first
                              if (index < _filteredReports.length) {
                                return _buildReportCard(
                                  _filteredReports[index],
                                  isDark,
                                );
                              }
                              // Then show old inspections
                              final inspectionIndex = index - _filteredReports.length;
                              return _buildInspectionCard(
                                _filteredInspections[inspectionIndex],
                                isDark,
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        backgroundColor: _accent.withValues(alpha: 0.1),
        side: BorderSide(color: _accent.withValues(alpha: 0.3)),
        labelPadding: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _showFilterSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _clearFilters();
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Technician filter (admin only)
                  if (_isAdmin && _technicians.isNotEmpty) ...[
                    _buildTechnicianFilterSection(isDark, ctx),
                    const SizedBox(height: 16),
                  ],
                  // Customer filter (admin only)
                  if (_isAdmin && _customers.isNotEmpty) ...[
                    _buildCustomerFilterSection(isDark, ctx),
                    const SizedBox(height: 16),
                  ],
                  // Category filter
                  _buildFilterSection(
                    'Job Category',
                    JobCategories.allCategories,
                    _filterCategory,
                    (value) {
                      setState(() => _filterCategory = value);
                      Navigator.pop(ctx);
                      _loadInspections();
                    },
                    isDark,
                  ),
                  const SizedBox(height: 16),
                  // Status filter
                  _buildFilterSection(
                    'Job Status',
                    CompletionStatus.all,
                    _filterStatus,
                    (value) {
                      setState(() => _filterStatus = value);
                      Navigator.pop(ctx);
                      _loadInspections();
                    },
                    isDark,
                    displayFn: CompletionStatus.getDisplay,
                  ),
                  const SizedBox(height: 16),
                  // Condition filter
                  _buildFilterSection(
                    'Condition',
                    ConditionRatings.all,
                    _filterCondition,
                    (value) {
                      setState(() => _filterCondition = value);
                      Navigator.pop(ctx);
                      _loadInspections();
                    },
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String? selectedValue,
    Function(String?) onSelect,
    bool isDark, {
    String Function(String)? displayFn,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            final displayText = displayFn?.call(option) ?? option;
            return ChoiceChip(
              label: Text(displayText),
              selected: isSelected,
              onSelected: (selected) {
                onSelect(selected ? option : null);
              },
              selectedColor: _accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? _accent : (isDark ? Colors.white : Colors.black87),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTechnicianFilterSection(bool isDark, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Technician',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _technicians.map((tech) {
            final isSelected = _filterTechnician == tech.username;
            return ChoiceChip(
              label: Text('${tech.displayName} (${tech.inspectionCount})'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterTechnician = selected ? tech.username : null);
                Navigator.pop(ctx);
                _loadInspections();
              },
              selectedColor: _accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? _accent : (isDark ? Colors.white : Colors.black87),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomerFilterSection(bool isDark, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _customers.map((customer) {
            final isSelected = _filterCustomer == customer;
            return ChoiceChip(
              label: Text(customer),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterCustomer = selected ? customer : null);
                Navigator.pop(ctx);
                _loadInspections();
              },
              selectedColor: _accent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? _accent : (isDark ? Colors.white : Colors.black87),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInspectionCard(Inspection inspection, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: InkWell(
        onTap: () => _openInspectionDetail(inspection),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address and date
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: _accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inspection.address,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Customer name if available
              if (inspection.customerName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  inspection.customerName!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Job category and type
              Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${inspection.jobCategory} - ${inspection.jobType}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Badges row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(inspection.chimneyType, Colors.blue, isDark),
                  _buildBadge(
                    inspection.condition,
                    _getConditionColor(inspection.condition),
                    isDark,
                  ),
                  _buildBadge(
                    inspection.completionStatusDisplay,
                    _getStatusColor(inspection.completionStatus),
                    isDark,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Time and technician info
              Row(
                children: [
                  // Date/Time
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          inspection.localSubmitTime != null
                              ? '${dateFormat.format(inspection.localSubmitTime!)} ${timeFormat.format(inspection.localSubmitTime!)}'
                              : dateFormat.format(inspection.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Photos count
                  if (inspection.photoCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${inspection.photoCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),

              // Admin view: show technician name
              if (_isAdmin) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'By: ${inspection.displayName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Good':
        return Colors.green;
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return Colors.deepOrange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'incomplete':
        return Colors.red;
      case 'follow_up_needed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReportCard(InspectionReportSummary report, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _accent.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _openReportDetail(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Report badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FULL REPORT',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    report.inspectionLevel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer name
              Text(
                report.clientName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),

              // Address
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 14,
                    color: _accent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      report.fullAddress,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // System type badge
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildBadge(report.systemType, Colors.blue, isDark),
                  if (report.hasFailedItems)
                    _buildBadge('Needs Attention', Colors.red, isDark)
                  else
                    _buildBadge('Passed', Colors.green, isDark),
                ],
              ),

              const SizedBox(height: 8),

              // Date/Time and inspector
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dateFormat.format(report.inspectionDate)} ${report.inspectionTime}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),

              // Inspector name (admin view)
              if (_isAdmin) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'By: ${report.inspectorName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openReportDetail(InspectionReportSummary report) {
    // Navigate to report detail view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InspectionReportDetailScreen(
          reportId: report.id,
          isAdmin: _isAdmin,
          onDeleted: _loadInspections,
          currentUsername: widget.username,
          currentRole: widget.role,
        ),
      ),
    );
  }
}
