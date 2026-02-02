// lib/hr/hr_screen.dart
// Human Resources employee management screen - List view layout with stats bar

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../app_theme.dart';
import 'hr_service.dart';

class HRScreen extends StatefulWidget {
  final String username;
  final String role;

  const HRScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<HRScreen> createState() => _HRScreenState();
}

class _HRScreenState extends State<HRScreen> {
  late HRService _service;
  List<HREmployee> _employees = [];
  List<HREmployee> _filteredEmployees = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  // Filter and sort state
  String _filterRole = 'all';
  String _filterStatus = 'all'; // 'all', 'active', 'on_leave', 'terminated'
  String _sortBy = 'name'; // 'name', 'role', 'days', 'date'
  bool _showInactive = false;

  static const Color _accent = AppColors.accent;

  // Available roles for filter dropdown
  static const List<String> _roles = [
    'dispatcher',
    'remote_dispatcher',
    'technician',
    'management',
    'marketing',
    'administrator',
    'developer',
    'franchise_manager',
  ];

  @override
  void initState() {
    super.initState();
    _service = HRService(username: widget.username, role: widget.role);
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final employees = await _service.getEmployees(includeInactive: _showInactive);
      if (mounted) {
        setState(() {
          _employees = employees;
          _isLoading = false;
        });
        _applyFilters();

        // Auto-sync profile pictures in background
        _autoSyncPictures();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _autoSyncPictures() async {
    try {
      final synced = await _service.autoSyncProfilePictures();
      if (synced > 0 && mounted) {
        // Reload to show updated pictures
        final employees = await _service.getEmployees(includeInactive: _showInactive);
        if (mounted) {
          setState(() {
            _employees = employees;
          });
          _applyFilters();
        }
      }
    } catch (e) {
      // Silent failure - auto-sync is not critical
    }
  }

  /// Centralized filter logic - eliminates duplicate code
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredEmployees = _employees.where((e) {
        // Search filter - removed SSN from search for security
        final matchesSearch = query.isEmpty ||
            e.fullName.toLowerCase().contains(query) ||
            (e.username?.toLowerCase().contains(query) ?? false) ||
            (e.role?.toLowerCase().contains(query) ?? false);

        // Role filter
        final matchesRole = _filterRole == 'all' || e.role == _filterRole;

        // Status filter
        final matchesStatus = _filterStatus == 'all' ||
            _getStatusCategory(e) == _filterStatus;

        return matchesSearch && matchesRole && matchesStatus;
      }).toList();

      // Apply sorting
      _filteredEmployees.sort(_compareEmployees);
    });
  }

  String _getStatusCategory(HREmployee e) {
    final status = e.employmentStatus?.toLowerCase() ?? '';
    if (status == 'active') return 'active';
    if (status == 'on leave' || status == 'on_leave') return 'on_leave';
    if (status == 'terminated') return 'terminated';
    if (!e.isActive) return 'terminated';
    return 'active';
  }

  int _compareEmployees(HREmployee a, HREmployee b) {
    switch (_sortBy) {
      case 'name':
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      case 'role':
        return (a.role ?? '').compareTo(b.role ?? '');
      case 'days':
        return (b.daysWorked ?? 0).compareTo(a.daysWorked ?? 0);
      case 'date':
        final dateA = a.dateOfEmployment ?? DateTime(1900);
        final dateB = b.dateOfEmployment ?? DateTime(1900);
        return dateB.compareTo(dateA);
      default:
        return 0;
    }
  }

  // Stats calculations
  int get _totalCount => _employees.length;
  int get _activeCount => _employees.where((e) => _getStatusCategory(e) == 'active').length;
  int get _onLeaveCount => _employees.where((e) => _getStatusCategory(e) == 'on_leave').length;
  int get _terminatedCount => _employees.where((e) => _getStatusCategory(e) == 'terminated').length;

  String _displayRole(String role) {
    return role.replaceAll('_', ' ').split(' ').map((w) =>
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
    ).join(' ');
  }

  Color _getStatusColor(HREmployee employee) {
    final status = _getStatusCategory(employee);
    switch (status) {
      case 'active':
        return Colors.green;
      case 'on_leave':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Human Resources'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
              _loadEmployees();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadEmployees,
          ),
        ],
      ),
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEmployeeDialog(context),
        backgroundColor: _accent,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Stats bar
          _buildStatsBar(isDark),

          // Filter bar
          _buildFilterBar(isDark),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _filteredEmployees.isEmpty
                        ? _buildEmptyState()
                        : _buildEmployeeList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildStatChip(
            label: 'Total',
            count: _totalCount,
            color: _accent,
            isSelected: _filterStatus == 'all',
            onTap: () {
              setState(() => _filterStatus = 'all');
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            label: 'Active',
            count: _activeCount,
            color: Colors.green,
            isSelected: _filterStatus == 'active',
            onTap: () {
              setState(() => _filterStatus = 'active');
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            label: 'On Leave',
            count: _onLeaveCount,
            color: Colors.orange,
            isSelected: _filterStatus == 'on_leave',
            onTap: () {
              setState(() => _filterStatus = 'on_leave');
              _applyFilters();
            },
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            label: 'Inactive',
            count: _terminatedCount,
            color: Colors.red,
            isSelected: _filterStatus == 'terminated',
            onTap: () {
              setState(() => _filterStatus = 'terminated');
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade400,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search by name, username, role...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Role filter
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: _filterRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Roles')),
                ..._roles.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_displayRole(r), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _filterRole = v);
                  _applyFilters();
                }
              },
            ),
          ),
          const SizedBox(width: 12),

          // Sort dropdown
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                labelText: 'Sort by',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Name A-Z')),
                DropdownMenuItem(value: 'role', child: Text('Role')),
                DropdownMenuItem(value: 'days', child: Text('Days Worked')),
                DropdownMenuItem(value: 'date', child: Text('Hire Date')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _sortBy = v);
                  _applyFilters();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadEmployees,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty || _filterRole != 'all' || _filterStatus != 'all'
                ? 'No employees match your filters'
                : 'No employees yet',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (_filterStatus != 'all' || _filterRole != 'all') ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _filterRole = 'all';
                  _filterStatus = 'all';
                  _searchController.clear();
                });
                _applyFilters();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeList(bool isDark) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        return _buildEmployeeListItem(_filteredEmployees[index], cardColor, isDark);
      },
    );
  }

  Widget _buildEmployeeListItem(HREmployee employee, Color cardColor, bool isDark) {
    final statusColor = _getStatusColor(employee);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showEmployeeDetails(employee),
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: employee.isActive ? 1.0 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with status indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _accent.withValues(alpha: 0.1),
                      backgroundImage: employee.profilePicture != null &&
                          employee.profilePicture!.isNotEmpty
                          ? NetworkImage(employee.profilePicture!)
                          : null,
                      child: employee.profilePicture == null ||
                          employee.profilePicture!.isEmpty
                          ? Text(
                              employee.firstName.isNotEmpty
                                  ? employee.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cardColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Employee info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and badges row
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employee.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Role badge
                          if (employee.role != null && employee.role!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                employee.roleDisplay,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _accent,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              employee.employmentStatus ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Subtitle row
                      Row(
                        children: [
                          if (employee.username != null)
                            Text(
                              '@${employee.username}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          if (employee.username != null && employee.daysWorked != null)
                            Text(
                              ' · ',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          if (employee.daysWorked != null)
                            Text(
                              '${employee.daysWorked} days',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Document icons (compact)
                _buildCompactDocIcons(employee),

                // Actions menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        _showEmployeeDetails(employee);
                        break;
                      case 'edit':
                        _showEmployeeDialog(context, employee: employee);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDocIcons(HREmployee employee) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompactDocIcon(
          icon: Icons.badge_outlined,
          hasDoc: employee.hasIdComplete,
          tooltip: 'ID',
          onTap: () => _showDocumentViewer(context, employee, 'id'),
        ),
        _buildCompactDocIcon(
          icon: Icons.description_outlined,
          hasDoc: employee.hasContract,
          tooltip: 'Contract',
          onTap: () => _showDocumentViewer(context, employee, 'contract'),
        ),
        _buildCompactDocIcon(
          icon: Icons.credit_card_outlined,
          hasDoc: employee.hasSsnDoc,
          tooltip: 'SSN',
          onTap: () => _showDocumentViewer(context, employee, 'ssn_doc'),
        ),
        _buildCompactDocIcon(
          icon: Icons.folder_outlined,
          hasDoc: employee.hasOtherDocs,
          tooltip: 'Other (${employee.otherDocsCount})',
          count: employee.otherDocsCount,
          onTap: () => _showDocumentViewer(context, employee, 'other'),
        ),
      ],
    );
  }

  Widget _buildCompactDocIcon({
    required IconData icon,
    required bool hasDoc,
    required String tooltip,
    int? count,
    required VoidCallback onTap,
  }) {
    final color = hasDoc ? _accent : Colors.grey.shade400;

    return Semantics(
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                Icon(icon, size: 18, color: color),
                if (count != null && count > 1)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 7,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDocumentViewer(BuildContext context, HREmployee employee, String docType) async {
    // Fetch full employee data to get documents
    try {
      debugPrint('HR: Fetching employee ${employee.id} for docType: $docType');
      final fullEmployee = await _service.getEmployee(employee.id);
      debugPrint('HR: Got employee, documents count: ${fullEmployee.documents.length}');
      debugPrint('HR: Document types: ${fullEmployee.documents.map((d) => d.documentType).join(", ")}');
      if (!context.mounted) return;

      List<HRDocument> docs;
      String title;

      switch (docType) {
        case 'id':
          docs = fullEmployee.idDocuments;
          title = 'ID Documents';
          break;
        case 'contract':
          docs = fullEmployee.contractDocuments;
          title = 'Contract';
          break;
        case 'ssn_doc':
          docs = fullEmployee.ssnDocuments;
          title = 'SSN Card';
          break;
        case 'other':
          docs = fullEmployee.otherDocuments;
          title = 'Other Documents';
          break;
        default:
          docs = [];
          title = 'Documents';
      }

      debugPrint('HR: Filtered docs for $docType: ${docs.length}');

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _DocumentViewerSheet(
          documents: docs,
          title: title,
          docType: docType,
          employee: fullEmployee,
          service: _service,
          onUpdated: () {},
        ),
      );

      // Refresh when modal closes
      if (!context.mounted) return;
      _loadEmployees();
    } catch (e) {
      debugPrint('HR: Error in _showDocumentViewer: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showEmployeeDetails(HREmployee employee) async {
    try {
      final fullEmployee = await _service.getEmployee(employee.id);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => _EmployeeDetailsSheet(
          employee: fullEmployee,
          service: _service,
          onUpdated: _loadEmployees,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showEmployeeDialog(BuildContext context, {HREmployee? employee}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EmployeeDialog(
        employee: employee,
        service: _service,
      ),
    );

    if (result == true) {
      _loadEmployees();
    }
  }
}

// Employee details bottom sheet
class _EmployeeDetailsSheet extends StatefulWidget {
  final HREmployee employee;
  final HRService service;
  final VoidCallback onUpdated;

  const _EmployeeDetailsSheet({
    required this.employee,
    required this.service,
    required this.onUpdated,
  });

  @override
  State<_EmployeeDetailsSheet> createState() => _EmployeeDetailsSheetState();
}

class _EmployeeDetailsSheetState extends State<_EmployeeDetailsSheet> {
  late HREmployee _employee;
  bool _isUploadingPicture = false;
  int _pictureRefreshKey = 0;

  static const Color _accent = AppColors.accent;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
  }

  Future<void> _refreshEmployee() async {
    try {
      final updated = await widget.service.getEmployee(_employee.id);
      setState(() => _employee = updated);
      widget.onUpdated();
    } catch (e) {
      // Ignore
    }
  }

  Widget _buildLargeInitial() {
    return Center(
      child: Text(
        _employee.firstName.isNotEmpty
            ? _employee.firstName[0].toUpperCase()
            : '?',
        style: const TextStyle(fontSize: 48, color: _accent),
      ),
    );
  }

  /// Mask sensitive numbers - show only last 4 digits
  String _maskNumber(String number) {
    if (number.length <= 4) return number;
    return '****${number.substring(number.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _employee.employmentStatus == 'Active'
        ? Colors.green
        : _employee.employmentStatus == 'Terminated'
            ? Colors.red
            : Colors.orange;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header with photo and name
                    Center(
                      child: Column(
                        children: [
                          // Profile picture with upload option
                          GestureDetector(
                            onTap: _uploadProfilePicture,
                            child: Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _accent.withValues(alpha: 0.1),
                                  ),
                                  child: _employee.profilePicture != null && _employee.profilePicture!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.network(
                                                _pictureRefreshKey > 0
                                                    ? '${_employee.profilePicture}?t=$_pictureRefreshKey'
                                                    : _employee.profilePicture!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _buildLargeInitial(),
                                              ),
                                              if (_isUploadingPicture)
                                                Container(
                                                  color: Colors.black45,
                                                  child: const Center(
                                                    child: CircularProgressIndicator(color: Colors.white),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )
                                      : _isUploadingPicture
                                          ? const Center(child: CircularProgressIndicator())
                                          : _buildLargeInitial(),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _accent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _employee.fullName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_employee.role != null && _employee.role!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _employee.roleDisplay,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          if (_employee.username != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '@${_employee.username}',
                                style: const TextStyle(color: _accent),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _employee.employmentStatus ?? 'Unknown',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 32),

                    // Details
                    if (_employee.dateOfEmployment != null)
                      _buildDetailItem('Date of Employment',
                          DateFormat('MMMM d, yyyy').format(_employee.dateOfEmployment!)),
                    if (_employee.dateOfTermination != null)
                      _buildDetailItem('Date of Termination',
                          DateFormat('MMMM d, yyyy').format(_employee.dateOfTermination!)),
                    if (_employee.daysWorked != null)
                      _buildDetailItem('Days Worked', '${_employee.daysWorked} days'),
                    if (_employee.birthday != null)
                      _buildDetailItem('Birthday',
                          DateFormat('MMMM d, yyyy').format(_employee.birthday!)),
                    if (_employee.ssn != null && _employee.ssn!.isNotEmpty)
                      _buildDetailItem('SSN', _maskNumber(_employee.ssn!)),

                    // Bank info section - masked for security
                    if (_employee.bankAccountNumber != null || _employee.bankRoutingNumber != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.account_balance, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Bank Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_employee.bankRoutingNumber != null && _employee.bankRoutingNumber!.isNotEmpty)
                        _buildDetailItem('Routing Number', _maskNumber(_employee.bankRoutingNumber!)),
                      if (_employee.bankAccountNumber != null && _employee.bankAccountNumber!.isNotEmpty)
                        _buildDetailItem('Account Number', _maskNumber(_employee.bankAccountNumber!)),
                      const SizedBox(height: 8),
                      const Divider(),
                    ],

                    if (_employee.notes != null && _employee.notes!.isNotEmpty)
                      _buildDetailItem('Notes', _employee.notes!),

                    const SizedBox(height: 24),

                    // Documents section
                    const Text(
                      'Documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Document type cards
                    Row(
                      children: [
                        Expanded(child: _buildDocTypeCard('ID', Icons.badge_outlined,
                            _employee.hasIdComplete, false,
                            _employee.hasIdComplete ? '1' : '0', 'id')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDocTypeCard('Contract', Icons.description_outlined,
                            _employee.hasContract, false,
                            _employee.hasContract ? '1' : '0', 'contract')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildDocTypeCard('SSN Card', Icons.credit_card_outlined,
                            _employee.hasSsnDoc, false,
                            _employee.hasSsnDoc ? '1' : '0', 'ssn_doc')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDocTypeCard('Other', Icons.folder_outlined,
                            _employee.hasOtherDocs, false,
                            '${_employee.otherDocsCount}', 'other')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocTypeCard(String title, IconData icon, bool hasDoc, bool isPartial, String count, String docType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = hasDoc ? _accent : isPartial ? Colors.orange : Colors.grey;

    return InkWell(
      onTap: () => _showDocumentViewer(docType),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDoc ? _accent.withValues(alpha: 0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDocumentViewer(String docType) async {
    List<HRDocument> docs;
    String title;

    switch (docType) {
      case 'id':
        docs = _employee.idDocuments;
        title = 'ID Documents';
        break;
      case 'contract':
        docs = _employee.contractDocuments;
        title = 'Contract';
        break;
      case 'ssn_doc':
        docs = _employee.ssnDocuments;
        title = 'SSN Card';
        break;
      case 'other':
        docs = _employee.otherDocuments;
        title = 'Other Documents';
        break;
      default:
        docs = [];
        title = 'Documents';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DocumentViewerSheet(
        documents: docs,
        title: title,
        docType: docType,
        employee: _employee,
        service: widget.service,
        onUpdated: () {},
      ),
    );

    // Refresh when modal closes
    if (mounted) {
      await _refreshEmployee();
    }
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadProfilePicture() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
            if (_employee.username != null)
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync from User Profile'),
                subtitle: const Text('Get picture from linked user account'),
                onTap: () => Navigator.pop(context, 'sync'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'sync') {
      await _syncPictureFromProfile();
    } else if (choice == 'upload') {
      await _uploadPictureFromGallery();
    }
  }

  Future<void> _syncPictureFromProfile() async {
    setState(() => _isUploadingPicture = true);

    try {
      final pictureUrl = await widget.service.syncPictureFromProfile(_employee.id);
      setState(() => _pictureRefreshKey++);
      await _refreshEmployee();

      if (mounted) {
        if (pictureUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture synced'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No profile picture found for this user'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploadingPicture = false);
    }
  }

  Future<void> _uploadPictureFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);

    if (picked == null || picked.path.isEmpty) return;

    setState(() => _isUploadingPicture = true);

    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      await widget.service.uploadPicture(_employee.id, base64Image);
      setState(() => _pictureRefreshKey++);
      await _refreshEmployee();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploadingPicture = false);
    }
  }
}

// Employee create/edit dialog
class _EmployeeDialog extends StatefulWidget {
  final HREmployee? employee;
  final HRService service;

  const _EmployeeDialog({
    this.employee,
    required this.service,
  });

  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _ssnController;
  late TextEditingController _notesController;
  late TextEditingController _roleController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankRoutingController;

  DateTime? _dateOfEmployment;
  DateTime? _dateOfTermination;
  DateTime? _birthday;
  String? _linkedUsername;
  List<AvailableUser> _availableUsers = [];
  bool _isLoading = false;
  bool _isSaving = false;

  bool get isEditing => widget.employee != null;

  static const List<String> _roles = [
    'dispatcher',
    'remote_dispatcher',
    'technician',
    'management',
    'marketing',
    'administrator',
    'developer',
    'franchise_manager',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.employee?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.employee?.lastName ?? '');
    _ssnController = TextEditingController(text: widget.employee?.ssn ?? '');
    _notesController = TextEditingController(text: widget.employee?.notes ?? '');
    _roleController = TextEditingController(text: widget.employee?.role ?? '');
    _bankAccountController = TextEditingController(text: widget.employee?.bankAccountNumber ?? '');
    _bankRoutingController = TextEditingController(text: widget.employee?.bankRoutingNumber ?? '');
    _dateOfEmployment = widget.employee?.dateOfEmployment;
    _dateOfTermination = widget.employee?.dateOfTermination;
    _birthday = widget.employee?.birthday;
    _linkedUsername = widget.employee?.username;
    _loadAvailableUsers();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ssnController.dispose();
    _notesController.dispose();
    _roleController.dispose();
    _bankAccountController.dispose();
    _bankRoutingController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await widget.service.getAvailableUsers();
      setState(() {
        _availableUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (isEditing) {
        await widget.service.updateEmployee(
          id: widget.employee!.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _roleController.text.trim(),
          dateOfEmployment: _dateOfEmployment,
          dateOfTermination: _dateOfTermination,
          birthday: _birthday,
          ssn: _ssnController.text.trim(),
          notes: _notesController.text.trim(),
          bankAccountNumber: _bankAccountController.text.trim(),
          bankRoutingNumber: _bankRoutingController.text.trim(),
        );

        // Handle username linking
        if (_linkedUsername != widget.employee!.username) {
          if (_linkedUsername == null && widget.employee!.username != null) {
            await widget.service.unlinkUser(widget.employee!.id);
          } else if (_linkedUsername != null) {
            await widget.service.linkUser(widget.employee!.id, _linkedUsername!);
          }
        }
      } else {
        await widget.service.createEmployee(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _roleController.text.trim(),
          dateOfEmployment: _dateOfEmployment,
          dateOfTermination: _dateOfTermination,
          birthday: _birthday,
          ssn: _ssnController.text.trim(),
          username: _linkedUsername,
          notes: _notesController.text.trim(),
          bankAccountNumber: _bankAccountController.text.trim(),
          bankRoutingNumber: _bankRoutingController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _selectDate(String field) async {
    DateTime initial;
    switch (field) {
      case 'employment':
        initial = _dateOfEmployment ?? DateTime.now();
        break;
      case 'termination':
        initial = _dateOfTermination ?? DateTime.now();
        break;
      case 'birthday':
        initial = _birthday ?? DateTime(1990, 1, 1);
        break;
      default:
        initial = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        switch (field) {
          case 'employment':
            _dateOfEmployment = picked;
            break;
          case 'termination':
            _dateOfTermination = picked;
            break;
          case 'birthday':
            _birthday = picked;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 500 ? screenWidth * 0.9 : 450.0;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Employee' : 'Add Employee'),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Role dropdown
                DropdownButtonFormField<String>(
                  value: _roles.contains(_roleController.text) ? _roleController.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: _roles.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.replaceAll('_', ' ').split(' ').map((w) =>
                      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
                    ).join(' ')),
                  )).toList(),
                  onChanged: (v) => setState(() => _roleController.text = v ?? ''),
                ),
                const SizedBox(height: 16),

                // Date of employment
                _buildDateField(
                  label: 'Date of Employment',
                  value: _dateOfEmployment,
                  onTap: () => _selectDate('employment'),
                  onClear: () => setState(() => _dateOfEmployment = null),
                ),
                const SizedBox(height: 16),

                // Date of termination
                _buildDateField(
                  label: 'Date of Termination',
                  value: _dateOfTermination,
                  onTap: () => _selectDate('termination'),
                  onClear: () => setState(() => _dateOfTermination = null),
                ),
                const SizedBox(height: 16),

                // Birthday
                _buildDateField(
                  label: 'Birthday',
                  value: _birthday,
                  onTap: () => _selectDate('birthday'),
                  onClear: () => setState(() => _birthday = null),
                ),
                const SizedBox(height: 16),

                // SSN
                TextFormField(
                  controller: _ssnController,
                  decoration: const InputDecoration(
                    labelText: 'SSN',
                    border: OutlineInputBorder(),
                    hintText: 'XXX-XX-XXXX',
                  ),
                ),
                const SizedBox(height: 16),

                // Link to user
                _isLoading
                    ? const CircularProgressIndicator()
                    : DropdownButtonFormField<String?>(
                        value: _linkedUsername,
                        decoration: const InputDecoration(
                          labelText: 'Link to User Account',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No linked user'),
                          ),
                          if (isEditing && widget.employee!.username != null)
                            DropdownMenuItem<String?>(
                              value: widget.employee!.username,
                              child: Text('${widget.employee!.username} (current)'),
                            ),
                          ..._availableUsers.map((u) => DropdownMenuItem<String?>(
                            value: u.username,
                            child: Text('${u.displayName} (@${u.username})'),
                          )),
                        ],
                        onChanged: (v) => setState(() => _linkedUsername = v),
                      ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // Bank Info Section
                Row(
                  children: [
                    Icon(Icons.account_balance, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Bank Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _bankRoutingController,
                  decoration: const InputDecoration(
                    labelText: 'Routing Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bankAccountController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null ? DateFormat('MMM d, yyyy').format(value) : 'Select date',
          style: TextStyle(
            color: value != null ? null : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

/// Document viewer sheet for viewing/uploading/deleting documents
class _DocumentViewerSheet extends StatefulWidget {
  final List<HRDocument> documents;
  final String title;
  final String docType;
  final HREmployee employee;
  final HRService service;
  final VoidCallback onUpdated;

  const _DocumentViewerSheet({
    required this.documents,
    required this.title,
    required this.docType,
    required this.employee,
    required this.service,
    required this.onUpdated,
  });

  @override
  State<_DocumentViewerSheet> createState() => _DocumentViewerSheetState();
}

class _DocumentViewerSheetState extends State<_DocumentViewerSheet> {
  static const Color _accent = AppColors.accent;
  bool _isUploading = false;
  bool _isDeleting = false;
  late List<HRDocument> _docs;

  @override
  void initState() {
    super.initState();
    _docs = List.from(widget.documents);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_getDocTypeIcon(), color: _accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.employee.fullName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Upload button
                if (_canUploadMore())
                  IconButton(
                    onPressed: _isUploading ? null : _uploadDocument,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_circle_outline),
                    color: _accent,
                    tooltip: 'Upload document',
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Documents list
          Flexible(
            child: _docs.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildDocumentTile(_docs[index]),
                  ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  IconData _getDocTypeIcon() {
    switch (widget.docType) {
      case 'id': return Icons.badge_outlined;
      case 'contract': return Icons.description_outlined;
      case 'ssn_doc': return Icons.credit_card_outlined;
      case 'other': return Icons.folder_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  bool _canUploadMore() {
    switch (widget.docType) {
      case 'id':
      case 'contract':
      case 'ssn_doc':
        return _docs.isEmpty;
      case 'other':
        return true;
      default:
        return true;
    }
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getDocTypeIcon(),
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${widget.title.toLowerCase()} uploaded',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadDocument,
            icon: _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Uploading...' : 'Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(HRDocument doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () => _previewDocument(doc),
        leading: Icon(
          _getFileIcon(doc.fileName),
          color: _accent,
        ),
        title: Text(
          doc.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          doc.typeLabel + (doc.uploadedAt != null
              ? ' • ${DateFormat('MMM d, yyyy').format(doc.uploadedAt!)}'
              : ''),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => _previewDocument(doc),
              tooltip: 'Preview',
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: () => _downloadDocument(doc),
              tooltip: 'Download',
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isDeleting ? null : () => _deleteDocument(doc),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewDocument(HRDocument doc) async {
    final ext = doc.fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    final url = await widget.service.getDocumentUrl(widget.employee.id, doc.id);

    if (!mounted) return;
    if (isImage) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.white,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error, size: 48, color: Colors.red),
                          SizedBox(height: 16),
                          Text('Failed to load image'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: FloatingActionButton.small(
                  heroTag: 'download',
                  backgroundColor: _accent,
                  onPressed: () => _downloadDocument(doc),
                  child: const Icon(Icons.download, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      await _openDocumentFile(doc, url);
    }
  }

  Future<void> _openDocumentFile(HRDocument doc, String url) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Opening document...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${doc.fileName}');
      await tempFile.writeAsBytes(response.bodyBytes);

      debugPrint('HR: Saved document to ${tempFile.path}');

      final result = await OpenFile.open(tempFile.path);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      debugPrint('HR: Error opening document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final file = result.files.first;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final base64Data = base64Encode(bytes);

      await widget.service.uploadDocument(
        employeeId: widget.employee.id,
        documentType: widget.docType,
        fileName: file.name,
        fileData: base64Data,
        label: null,
      );

      final updated = await widget.service.getEmployee(widget.employee.id);

      setState(() {
        switch (widget.docType) {
          case 'id':
            _docs = updated.idDocuments;
            break;
          case 'contract':
            _docs = updated.contractDocuments;
            break;
          case 'ssn_doc':
            _docs = updated.ssnDocuments;
            break;
          case 'other':
            _docs = updated.otherDocuments;
            break;
        }
      });

      widget.onUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadDocument(HRDocument doc) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Downloading...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final url = await widget.service.getDocumentUrl(widget.employee.id, doc.id);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Cannot access Downloads folder');
      }

      final fileName = doc.fileName;
      var destFile = File('${downloadsDir.path}/$fileName');
      int counter = 1;
      while (await destFile.exists()) {
        final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
        final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
        destFile = File('${downloadsDir.path}/$baseName ($counter)$ext');
        counter++;
      }

      await destFile.writeAsBytes(response.bodyBytes);
      debugPrint('HR: Downloaded document to ${destFile.path}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: ${destFile.path.split(Platform.pathSeparator).last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                await OpenFile.open(destFile.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('HR: Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(HRDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      await widget.service.deleteDocument(widget.employee.id, doc.id);

      setState(() {
        _docs.removeWhere((d) => d.id == doc.id);
      });

      widget.onUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDeleting = false);
    }
  }
}
