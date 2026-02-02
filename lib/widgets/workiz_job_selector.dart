import 'package:flutter/material.dart';
import '../features/integration/workiz_service.dart';

/// Widget for selecting a Workiz job to populate inspection form
/// Search-only mode: technicians must enter the job number to find a job
class WorkizJobSelector extends StatefulWidget {
  final Function(WorkizJob) onJobSelected;
  final WorkizJob? selectedJob;
  final bool showSyncButton;

  /// Location code for multi-location Workiz integration
  final String? locationCode;
  /// Username for checking location access
  final String? username;

  const WorkizJobSelector({
    super.key,
    required this.onJobSelected,
    this.selectedJob,
    this.showSyncButton = false, // Default to false - search only mode
    this.locationCode,
    this.username,
  });

  @override
  State<WorkizJobSelector> createState() => _WorkizJobSelectorState();
}

class _WorkizJobSelectorState extends State<WorkizJobSelector> {
  final WorkizService _workizService = WorkizService();
  final TextEditingController _searchController = TextEditingController();

  List<WorkizJob> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  WorkizConfigStatus? _configStatus;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Set user context for location-based operations
    if (widget.username != null) {
      _workizService.setUserContext(widget.username!, widget.locationCode);
    }
    _checkConfig();
  }

  @override
  void didUpdateWidget(WorkizJobSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update context if location changed
    if (oldWidget.locationCode != widget.locationCode ||
        oldWidget.username != widget.username) {
      if (widget.username != null) {
        _workizService.setUserContext(widget.username!, widget.locationCode);
      }
      _checkConfig();
    }
  }

  Future<void> _checkConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _configStatus = await _workizService.getConfigStatus(
        locationCode: widget.locationCode,
      );
      // Don't load all jobs - we only search now
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _workizService.searchJobs(
        query,
        locationCode: widget.locationCode,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _hasSearched = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed: ${e.toString()}';
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _configStatus == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_configStatus?.isConfigured != true) {
      return _buildNotConfigured();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'Find Workiz Job',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Search field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter job number...',
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
          keyboardType: TextInputType.number,
          onChanged: _search,
        ),
        const SizedBox(height: 4),
        Text(
          'Enter the Workiz job number to find the job',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),

        // Selected job display
        if (widget.selectedJob != null) ...[
          _buildSelectedJob(widget.selectedJob!),
          const SizedBox(height: 8),
        ],

        // Error message
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

        // Search results or prompt
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _buildSearchResults(),
      ],
    );
  }

  Widget _buildNotConfigured() {
    // Determine the specific reason for not being configured
    final bool noLocation = widget.locationCode == null || widget.locationCode!.isEmpty;
    final bool noApiToken = _configStatus?.hasApiToken != true;

    String title;
    String message;

    if (noLocation) {
      title = 'No Location Selected';
      message = 'Select a location for this inspection to enable Workiz integration.';
    } else if (noApiToken) {
      title = 'Workiz Not Configured';
      message = 'This location needs Workiz API credentials. Ask an admin to configure them in Settings > Workiz Integration.';
    } else {
      title = 'Workiz Connection Issue';
      message = _configStatus?.message ?? 'Unable to connect to Workiz. Please try again later.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedJob(WorkizJob job) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (job.fullAddress.isNotEmpty)
                  Text(
                    job.fullAddress,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Clear selection - parent should handle this
              widget.onJobSelected(WorkizJob(id: -1)); // Signal to clear
            },
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    // Show prompt if no search yet
    if (!_hasSearched || _searchController.text.length < 2) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Enter a job number to search',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Show no results message
    if (_searchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No jobs found for "${_searchController.text}"',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Check the job number and try again',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Show search results
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final job = _searchResults[index];
          final isSelected = widget.selectedJob?.id == job.id;

          return ListTile(
            selected: isSelected,
            selectedTileColor: Colors.blue.shade50,
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
              child: Text(
                job.workizSerialId?.substring(0, 1).toUpperCase() ?? '#',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              job.displayLabel,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (job.fullAddress.isNotEmpty)
                  Text(
                    job.fullAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (job.scheduledDate != null || job.clientPhone != null)
                  Row(
                    children: [
                      if (job.scheduledDate != null) ...[
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          '${job.scheduledDate!.month}/${job.scheduledDate!.day}/${job.scheduledDate!.year}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                      if (job.clientPhone != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          job.clientPhone!,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.blue)
                : const Icon(Icons.chevron_right),
            onTap: () => widget.onJobSelected(job),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Compact job selector for inline use
class WorkizJobSelectorCompact extends StatelessWidget {
  final WorkizJob? selectedJob;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const WorkizJobSelectorCompact({
    super.key,
    this.selectedJob,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedJob != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.work, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedJob!.displayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  if (selectedJob!.clientFullName.isNotEmpty)
                    Text(
                      selectedJob!.clientFullName,
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: Icon(Icons.close, color: Colors.blue.shade700, size: 18),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.work_outline),
      label: const Text('Select Workiz Job'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
