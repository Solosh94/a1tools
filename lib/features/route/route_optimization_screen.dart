// Route Optimization Screen
//
// Displays optimized routes for technicians with multiple job stops.
// Integrates with Google Maps for visualization.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';
import '../../config/api_config.dart';
import 'route_optimization_service.dart';

class RouteOptimizationScreen extends StatefulWidget {
  final String username;
  final String? locationCode;

  const RouteOptimizationScreen({
    super.key,
    required this.username,
    this.locationCode,
  });

  @override
  State<RouteOptimizationScreen> createState() => _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState extends State<RouteOptimizationScreen> {
  static const Color _accent = AppColors.accent;

  final RouteOptimizationService _service = RouteOptimizationService();

  bool _loading = true;
  bool _optimizing = false;
  String? _error;

  List<JobStop> _originalStops = [];
  List<JobStop> _optimizedStops = [];
  RouteOptimizationResult? _result;

  LatLng? _currentLocation;
  LatLng? _officeLocation;

  bool _returnToOffice = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _service.initialize();
      await _getCurrentLocation();
      await _loadTodaysJobs();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadTodaysJobs() async {
    final jobs = await _service.getTodaysJobs(widget.username);
    setState(() {
      _originalStops = jobs;
      _optimizedStops = List.from(jobs);
    });
  }

  Future<void> _optimizeRoute() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services to optimize route'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_originalStops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No jobs to optimize'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _optimizing = true;
    });

    try {
      final result = await _service.optimizeRoute(
        startLocation: _currentLocation!,
        stops: _originalStops,
        endLocation: _returnToOffice ? _officeLocation : null,
      );

      if (result.success && result.optimizedStops != null) {
        setState(() {
          _optimizedStops = result.optimizedStops!;
          _result = result;
        });

        // Save optimized route
        await _service.saveOptimizedRoute(widget.username, _optimizedStops);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Route optimized! Total: ${result.totalDistanceDisplay}, ${result.totalDurationDisplay}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to optimize route'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _optimizing = false;
      });
    }
  }

  Future<void> _openInMaps() async {
    if (_optimizedStops.isEmpty) return;

    // Build Google Maps URL with waypoints
    final origin = _currentLocation != null
        ? '${_currentLocation!.latitude},${_currentLocation!.longitude}'
        : _optimizedStops.first.address;

    final destination = _returnToOffice && _officeLocation != null
        ? '${_officeLocation!.latitude},${_officeLocation!.longitude}'
        : _optimizedStops.last.address;

    final waypoints = _optimizedStops
        .sublist(0, _optimizedStops.length - (_returnToOffice ? 0 : 1))
        .map((s) => Uri.encodeComponent(s.address))
        .join('|');

    final url = Platform.isIOS
        ? 'comgooglemaps://?saddr=$origin&daddr=$destination&waypoints=$waypoints&directionsmode=driving'
        : ApiConfig.googleMapsDirectionsUrl(origin: origin, destination: destination, waypoints: waypoints);

    final fallbackUrl = ApiConfig.googleMapsDirectionsUrl(origin: origin, destination: destination, waypoints: waypoints);

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _optimizedStops.removeAt(oldIndex);
      _optimizedStops.insert(newIndex, item);
      _result = null; // Clear result when manually reordered
    });
  }

  Future<void> _addStop() async {
    final addressController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stop'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                hintText: 'Enter full address',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'address': addressController.text,
            }),
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result['address']?.isNotEmpty == true) {
      final location = await _service.geocodeAddress(result['address']);
      if (location != null) {
        setState(() {
          _optimizedStops.add(JobStop(
            jobId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
            customerName: 'Manual Stop',
            address: result['address'],
            location: location,
          ));
          _result = null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find address'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _removeStop(int index) {
    setState(() {
      _optimizedStops.removeAt(index);
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Route Optimization'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (_optimizedStops.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: _addStop,
              tooltip: 'Add Stop',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildErrorState()
              : _buildContent(isDark),
      floatingActionButton: !_loading && _optimizedStops.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'optimize',
                  onPressed: _optimizing ? null : _optimizeRoute,
                  backgroundColor: _accent,
                  icon: _optimizing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_optimizing ? 'Optimizing...' : 'Optimize Route'),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'navigate',
                    onPressed: _openInMaps,
                    backgroundColor: Colors.green,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                ],
              ],
            )
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade300),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_optimizedStops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 64,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 16),
              Text(
                'No jobs scheduled for today',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _addStop,
                icon: const Icon(Icons.add_location),
                label: const Text('Add Manual Stop'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary card
        if (_result != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: _accent, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optimized Route',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_result!.totalDistanceDisplay} - ${_result!.totalDurationDisplay}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_optimizedStops.length} stops',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        // Options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: _returnToOffice,
                  onChanged: (value) {
                    setState(() {
                      _returnToOffice = value ?? false;
                      _result = null;
                    });
                  },
                  title: const Text('Return to office'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  checkColor: Colors.white,
                  activeColor: _accent,
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // Current location indicator
        if (_currentLocation != null)
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
            title: const Text('Your Current Location'),
            subtitle: Text(
              '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),

        const Divider(),

        // Stops list (reorderable)
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 160),
            itemCount: _optimizedStops.length,
            onReorder: _reorderStops,
            itemBuilder: (context, index) {
              final stop = _optimizedStops[index];
              return _buildStopTile(stop, index, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStopTile(JobStop stop, int index, bool isDark) {
    return Dismissible(
      key: ValueKey(stop.jobId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeStop(index),
      child: Card(
        key: ValueKey('card_${stop.jobId}'),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            stop.customerName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.address,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              if (stop.jobType != null)
                Text(
                  stop.jobType!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _accent,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stop.workizSerialId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${stop.workizSerialId}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.drag_handle),
            ],
          ),
          onTap: () => _showStopDetails(stop),
        ),
      ),
    );
  }

  void _showStopDetails(JobStop stop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: _accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stop.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              stop.address,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (stop.jobType != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.work_outline, size: 16, color: _accent),
                  const SizedBox(width: 8),
                  Text(stop.jobType!),
                ],
              ),
            ],
            if (stop.scheduledTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: _accent),
                  const SizedBox(width: 8),
                  Text(_formatTime(stop.scheduledTime!)),
                ],
              ),
            ],
            if (stop.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stop.notes!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigateToStop(stop);
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _callCustomer(stop);
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  Future<void> _navigateToStop(JobStop stop) async {
    final url = Platform.isIOS
        ? 'comgooglemaps://?daddr=${Uri.encodeComponent(stop.address)}&directionsmode=driving'
        : ApiConfig.googleMapsDirectionsUrl(origin: '', destination: stop.address);

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  Future<void> _callCustomer(JobStop stop) async {
    // This would need customer phone from job data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number not available')),
    );
  }
}
