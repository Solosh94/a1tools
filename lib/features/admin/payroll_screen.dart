import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import '../../core/services/payroll_service.dart';

class PayrollScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const PayrollScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Date range
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _toDate = DateTime.now();

  // Data
  List<PayrollRate> _rates = [];
  EarningsReport? _earnings;
  PayrollSummary? _summary;

  // Loading states
  bool _loadingRates = true;
  bool _loadingEarnings = true;
  bool _loadingSummary = true;

  // Currency formatter
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _numberFormat = NumberFormat('#,##0.00');

  // Roles to exclude from payroll (no hourly rate applicable)
  static const _excludedRoles = {'technician', 'administrator', 'developer'};

  /// Check if a role should be excluded from payroll
  bool _isExcludedRole(String? role) {
    if (role == null) return false;
    return _excludedRoles.contains(role.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadRates(),
      _loadEarnings(),
      _loadSummary(),
    ]);
  }

  Future<void> _loadRates() async {
    setState(() => _loadingRates = true);
    final rates = await PayrollService.instance.getRates();
    if (mounted) {
      setState(() {
        _rates = rates;
        _loadingRates = false;
      });
    }
  }

  Future<void> _loadEarnings() async {
    setState(() => _loadingEarnings = true);
    final earnings = await PayrollService.instance.getEarnings(
      from: _fromDate,
      to: _toDate,
    );
    if (mounted) {
      setState(() {
        _earnings = earnings;
        _loadingEarnings = false;
      });
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    final summary = await PayrollService.instance.getSummary(
      from: _fromDate,
      to: _toDate,
    );
    if (mounted) {
      setState(() {
        _summary = summary;
        _loadingSummary = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.accent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadEarnings();
      _loadSummary();
    }
  }

  Future<void> _showSetRateDialog(PayrollRate rate) async {
    final hourlyController = TextEditingController(
      text: rate.hourlyRate?.toStringAsFixed(2) ?? '',
    );
    final overtimeController = TextEditingController(
      text: rate.overtimeRate?.toStringAsFixed(2) ?? '',
    );
    final notesController = TextEditingController(text: rate.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Rate for ${rate.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hourlyController,
                decoration: const InputDecoration(
                  labelText: 'Hourly Rate (\$)',
                  prefixText: '\$ ',
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: overtimeController,
                decoration: const InputDecoration(
                  labelText: 'Overtime Rate (\$) - Optional',
                  prefixText: '\$ ',
                  hintText: 'Leave blank for 1.5x regular',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'e.g., Full-time, Part-time',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final hourlyRate = double.tryParse(hourlyController.text);
      if (hourlyRate == null || hourlyRate < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a valid hourly rate'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final overtimeRate = double.tryParse(overtimeController.text);

      final success = await PayrollService.instance.setRate(
        username: rate.username,
        hourlyRate: hourlyRate,
        overtimeRate: overtimeRate,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
        updatedBy: widget.currentUsername,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rate updated for ${rate.displayName}'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadRates();
          _loadEarnings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update rate'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: 'Earnings', icon: Icon(Icons.attach_money, size: 20)),
            Tab(text: 'Rates', icon: Icon(Icons.settings, size: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Date Range',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: Column(
        children: [
          // Date range indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.accent.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.date_range, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM d, y').format(_fromDate)} - ${DateFormat('MMM d, y').format(_toDate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
                TextButton(
                  onPressed: _selectDateRange,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isDark),
                _buildEarningsTab(isDark),
                _buildRatesTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    if (_loadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Failed to load summary'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Payroll',
                  value: _currencyFormat.format(_summary!.totalPayroll),
                  change: _summary!.payrollChangePercent,
                  icon: Icons.attach_money,
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Hours',
                  value: '${_numberFormat.format(_summary!.totalHours)}h',
                  change: _summary!.hoursChangePercent,
                  icon: Icons.access_time,
                  cardColor: cardColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Employees',
                  value: '${_summary!.employeeCount}',
                  icon: Icons.people,
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Records',
                  value: '${_summary!.totalRecords}',
                  icon: Icons.receipt_long,
                  cardColor: cardColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top earners
          Text(
            'Top Earners',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: cardColor,
            child: _summary!.topEarners.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No data for this period')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _summary!.topEarners.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final earner = _summary!.topEarners[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(earner.displayName),
                        subtitle: Text('${_numberFormat.format(earner.hours)} hours'),
                        trailing: Text(
                          _currencyFormat.format(earner.earnings),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    double? change,
    required IconData icon,
    required Color cardColor,
  }) {
    final isPositive = change != null && change >= 0;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (change != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: isPositive ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPositive ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ' vs prev',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsTab(bool isDark) {
    if (_loadingEarnings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_earnings == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Failed to load earnings'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadEarnings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    // Filter out technicians and admins (they don't have hourly rates)
    final filteredEmployees = _earnings!.employees
        .where((e) => !_isExcludedRole(e.role))
        .toList();

    // Recalculate totals for filtered employees
    final filteredTotalPayroll = filteredEmployees.fold<double>(
        0, (sum, e) => sum + e.grossPay);
    final filteredTotalHours = filteredEmployees.fold<double>(
        0, (sum, e) => sum + e.totalHours);

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(16),
          color: cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Total', _currencyFormat.format(filteredTotalPayroll)),
              _buildStat('Hours', '${_numberFormat.format(filteredTotalHours)}h'),
              _buildStat('Employees', '${filteredEmployees.length}'),
            ],
          ),
        ),
        const Divider(height: 1),
        // Employee list
        Expanded(
          child: filteredEmployees.isEmpty
              ? const Center(child: Text('No earnings data for this period'))
              : ListView.builder(
                  itemCount: filteredEmployees.length,
                  itemBuilder: (context, index) {
                    final emp = filteredEmployees[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: cardColor,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: emp.rateSet
                              ? AppColors.accent.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                          child: Text(
                            emp.displayName.isNotEmpty
                                ? emp.displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: emp.rateSet ? AppColors.accent : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(emp.displayName),
                        subtitle: Text(
                          '${_numberFormat.format(emp.totalHours)}h • ${emp.daysWorked} days',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _currencyFormat.format(emp.grossPay),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: emp.rateSet ? AppColors.success : Colors.grey,
                              ),
                            ),
                            if (!emp.rateSet)
                              const Text(
                                'No rate set',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.warning,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildDetailRow('Hourly Rate', _currencyFormat.format(emp.hourlyRate)),
                                _buildDetailRow('Regular Hours', '${_numberFormat.format(emp.regularHours)}h'),
                                _buildDetailRow('Regular Pay', _currencyFormat.format(emp.regularPay)),
                                if (emp.overtimeHours > 0) ...[
                                  const Divider(),
                                  _buildDetailRow('Overtime Rate', _currencyFormat.format(emp.overtimeRate)),
                                  _buildDetailRow('Overtime Hours', '${_numberFormat.format(emp.overtimeHours)}h'),
                                  _buildDetailRow('Overtime Pay', _currencyFormat.format(emp.overtimePay)),
                                ],
                                const Divider(),
                                _buildDetailRow(
                                  'Gross Pay',
                                  _currencyFormat.format(emp.grossPay),
                                  isBold: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatesTab(bool isDark) {
    if (_loadingRates) {
      return const Center(child: CircularProgressIndicator());
    }

    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    // Filter out technicians and admins (they don't have hourly rates)
    final filteredRates = _rates.where((r) => !_isExcludedRole(r.role)).toList();

    // Separate active and inactive, then those with/without rates
    final activeWithRate = filteredRates.where((r) => r.isActive && r.hasRate).toList();
    final activeWithoutRate = filteredRates.where((r) => r.isActive && !r.hasRate).toList();
    final inactive = filteredRates.where((r) => !r.isActive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Warning for employees without rates
        if (activeWithoutRate.isNotEmpty) ...[
          Card(
            color: AppColors.warning.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.warning),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${activeWithoutRate.length} employee${activeWithoutRate.length != 1 ? 's' : ''} without hourly rate set',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Active employees with rates
        if (activeWithRate.isNotEmpty) ...[
          Text(
            'Active Employees',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          ...activeWithRate.map((rate) => _buildRateCard(rate, cardColor)),
        ],

        // Active employees without rates
        if (activeWithoutRate.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Needs Rate Setup',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 8),
          ...activeWithoutRate.map((rate) => _buildRateCard(rate, cardColor)),
        ],

        // Inactive employees
        if (inactive.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Inactive Employees',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          ...inactive.map((rate) => _buildRateCard(rate, cardColor, isInactive: true)),
        ],
      ],
    );
  }

  Widget _buildRateCard(PayrollRate rate, Color cardColor, {bool isInactive = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isInactive ? cardColor.withValues(alpha: 0.5) : cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rate.hasRate
              ? AppColors.accent.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
          child: Text(
            rate.displayName.isNotEmpty
                ? rate.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: rate.hasRate ? AppColors.accent : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          rate.displayName,
          style: TextStyle(
            color: isInactive ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          rate.role ?? 'No role',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rate.hasRate)
              Text(
                _currencyFormat.format(rate.hourlyRate),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            else
              const Text(
                'Not set',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: isInactive ? null : () => _showSetRateDialog(rate),
              tooltip: 'Edit Rate',
            ),
          ],
        ),
      ),
    );
  }
}
