// Route Optimization Service
//
// Handles GPS route optimization for technicians with multiple job stops.
// Integrates with Google Maps API for directions and distance calculations.
//
// Note: Google Maps API calls use http directly since they are external APIs.
// Internal API calls use the unified ApiClient.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

class RouteOptimizationService {
  static const String _baseUrl = ApiConfig.apiBase;

  // Singleton pattern
  static final RouteOptimizationService _instance = RouteOptimizationService._internal();
  factory RouteOptimizationService() => _instance;
  RouteOptimizationService._internal();

  final ApiClient _api = ApiClient.instance;
  String? _googleMapsApiKey;

  /// Initialize the service with API key
  Future<void> initialize() async {
    try {
      final response = await _api.get('$_baseUrl/route_optimization.php?action=get_api_key');
      if (response.success) {
        _googleMapsApiKey = response.rawJson?['api_key'];
      }
    } catch (e) {
      debugPrint('Error initializing route optimization: $e');
    }
  }

  /// Get optimized route for a list of job stops
  /// Returns stops in optimal order to minimize travel time
  Future<RouteOptimizationResult> optimizeRoute({
    required LatLng startLocation,
    required List<JobStop> stops,
    LatLng? endLocation,
  }) async {
    if (stops.isEmpty) {
      return RouteOptimizationResult(
        success: false,
        error: 'No stops provided',
      );
    }

    if (stops.length == 1) {
      return RouteOptimizationResult(
        success: true,
        optimizedStops: stops,
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
      );
    }

    try {
      // Calculate distance matrix between all points
      final allPoints = [startLocation, ...stops.map((s) => s.location)];
      if (endLocation != null) {
        allPoints.add(endLocation);
      }

      final distanceMatrix = await _getDistanceMatrix(allPoints);
      if (distanceMatrix == null) {
        // Fallback to simple nearest neighbor if API fails
        return _nearestNeighborOptimization(startLocation, stops, endLocation);
      }

      // Use nearest neighbor algorithm with distance matrix
      final optimizedOrder = _optimizeWithMatrix(distanceMatrix, stops.length, endLocation != null);

      final optimizedStops = optimizedOrder.map((i) => stops[i]).toList();

      // Calculate total distance and duration
      int totalDistance = 0;
      int totalDuration = 0;

      int currentIndex = 0; // Start location
      for (final stopIndex in optimizedOrder) {
        totalDistance += distanceMatrix[currentIndex][stopIndex + 1]['distance'] ?? 0;
        totalDuration += distanceMatrix[currentIndex][stopIndex + 1]['duration'] ?? 0;
        currentIndex = stopIndex + 1;
      }

      if (endLocation != null) {
        final endIndex = allPoints.length - 1;
        totalDistance += distanceMatrix[currentIndex][endIndex]['distance'] ?? 0;
        totalDuration += distanceMatrix[currentIndex][endIndex]['duration'] ?? 0;
      }

      // Get route polyline for display
      final routePolyline = await _getRoutePolyline(
        startLocation,
        optimizedStops,
        endLocation,
      );

      return RouteOptimizationResult(
        success: true,
        optimizedStops: optimizedStops,
        totalDistanceMeters: totalDistance,
        totalDurationSeconds: totalDuration,
        routePolyline: routePolyline,
      );
    } catch (e) {
      debugPrint('Error optimizing route: $e');
      return _nearestNeighborOptimization(startLocation, stops, endLocation);
    }
  }

  /// Get distance matrix from Google Maps API
  Future<List<List<Map<String, int>>>?> _getDistanceMatrix(List<LatLng> points) async {
    if (_googleMapsApiKey == null) return null;

    try {
      final origins = points.map((p) => '${p.latitude},${p.longitude}').join('|');
      final destinations = origins;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.googleMapsDistanceMatrix}'
          '?origins=$origins'
          '&destinations=$destinations'
          '&key=$_googleMapsApiKey'
          '&units=imperial'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final rows = data['rows'] as List;
          final matrix = <List<Map<String, int>>>[];

          for (final row in rows) {
            final elements = row['elements'] as List;
            final rowData = <Map<String, int>>[];

            for (final element in elements) {
              if (element['status'] == 'OK') {
                rowData.add({
                  'distance': element['distance']['value'] as int,
                  'duration': element['duration']['value'] as int,
                });
              } else {
                rowData.add({'distance': 999999, 'duration': 999999});
              }
            }
            matrix.add(rowData);
          }
          return matrix;
        }
      }
    } catch (e) {
      debugPrint('Error getting distance matrix: $e');
    }
    return null;
  }

  /// Optimize route using distance matrix with nearest neighbor algorithm
  List<int> _optimizeWithMatrix(
    List<List<Map<String, int>>> matrix,
    int numStops,
    bool hasEndLocation,
  ) {
    final visited = <int>{};
    final order = <int>[];
    int current = 0; // Start at origin

    while (order.length < numStops) {
      int? nearest;
      int nearestDistance = 999999999;

      for (int i = 0; i < numStops; i++) {
        if (!visited.contains(i)) {
          final distance = matrix[current][i + 1]['distance'] ?? 999999999;
          if (distance < nearestDistance) {
            nearestDistance = distance;
            nearest = i;
          }
        }
      }

      if (nearest != null) {
        visited.add(nearest);
        order.add(nearest);
        current = nearest + 1;
      } else {
        break;
      }
    }

    return order;
  }

  /// Fallback optimization using haversine distance
  RouteOptimizationResult _nearestNeighborOptimization(
    LatLng start,
    List<JobStop> stops,
    LatLng? end,
  ) {
    final remaining = List<JobStop>.from(stops);
    final optimized = <JobStop>[];
    var current = start;
    double totalDistance = 0;

    while (remaining.isNotEmpty) {
      JobStop? nearest;
      double nearestDistance = double.infinity;

      for (final stop in remaining) {
        final distance = _haversineDistance(current, stop.location);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = stop;
        }
      }

      if (nearest != null) {
        totalDistance += nearestDistance;
        optimized.add(nearest);
        current = nearest.location;
        remaining.remove(nearest);
      }
    }

    if (end != null) {
      totalDistance += _haversineDistance(current, end);
    }

    return RouteOptimizationResult(
      success: true,
      optimizedStops: optimized,
      totalDistanceMeters: (totalDistance * 1000).round(),
      totalDurationSeconds: ((totalDistance / 50) * 3600).round(), // Estimate 50 km/h avg
    );
  }

  /// Calculate haversine distance between two points in kilometers
  double _haversineDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(p1.latitude)) *
        math.cos(_toRadians(p2.latitude)) *
        math.sin(dLon / 2) *
        math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Get route polyline for map display
  Future<String?> _getRoutePolyline(
    LatLng start,
    List<JobStop> stops,
    LatLng? end,
  ) async {
    if (_googleMapsApiKey == null || stops.isEmpty) return null;

    try {
      final waypoints = stops.map((s) => '${s.location.latitude},${s.location.longitude}').join('|');
      final destination = end ?? stops.last.location;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.googleMapsDirections}'
          '?origin=${start.latitude},${start.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&waypoints=optimize:false|$waypoints'
          '&key=$_googleMapsApiKey'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['routes'][0]['overview_polyline']['points'];
        }
      }
    } catch (e) {
      debugPrint('Error getting route polyline: $e');
    }
    return null;
  }

  /// Geocode an address to coordinates
  Future<LatLng?> geocodeAddress(String address) async {
    if (_googleMapsApiKey == null) return null;

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.googleMapsGeocode}'
          '?address=${Uri.encodeComponent(address)}'
          '&key=$_googleMapsApiKey'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
    } catch (e) {
      debugPrint('Error geocoding address: $e');
    }
    return null;
  }

  /// Get today's jobs for a technician
  Future<List<JobStop>> getTodaysJobs(String username) async {
    try {
      final response = await _api.get(
        '$_baseUrl/route_optimization.php?action=get_todays_jobs&username=$username',
      );

      if (response.success && response.rawJson?['jobs'] != null) {
        return (response.rawJson!['jobs'] as List)
            .map((j) => JobStop.fromJson(j))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting today\'s jobs: $e');
    }
    return [];
  }

  /// Save optimized route order
  Future<bool> saveOptimizedRoute(String username, List<JobStop> stops) async {
    try {
      final response = await _api.post(
        '$_baseUrl/route_optimization.php',
        body: {
          'action': 'save_route',
          'username': username,
          'stops': stops.map((s) => {
            'job_id': s.jobId,
            'order': stops.indexOf(s),
          }).toList(),
        },
      );

      return response.success;
    } catch (e) {
      debugPrint('Error saving optimized route: $e');
    }
    return false;
  }
}

/// Result of route optimization
class RouteOptimizationResult {
  final bool success;
  final List<JobStop>? optimizedStops;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final String? routePolyline;
  final String? error;

  RouteOptimizationResult({
    required this.success,
    this.optimizedStops,
    this.totalDistanceMeters = 0,
    this.totalDurationSeconds = 0,
    this.routePolyline,
    this.error,
  });

  String get totalDistanceDisplay {
    final miles = totalDistanceMeters / 1609.34;
    return '${miles.toStringAsFixed(1)} mi';
  }

  String get totalDurationDisplay {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }
}

/// A job stop with location
class JobStop {
  final String jobId;
  final String? workizSerialId;
  final String customerName;
  final String address;
  final LatLng location;
  final String? jobType;
  final DateTime? scheduledTime;
  final String? notes;
  final int? estimatedDurationMinutes;

  JobStop({
    required this.jobId,
    this.workizSerialId,
    required this.customerName,
    required this.address,
    required this.location,
    this.jobType,
    this.scheduledTime,
    this.notes,
    this.estimatedDurationMinutes,
  });

  factory JobStop.fromJson(Map<String, dynamic> json) {
    return JobStop(
      jobId: json['job_id']?.toString() ?? '',
      workizSerialId: json['workiz_serial_id'],
      customerName: json['customer_name'] ?? '',
      address: json['address'] ?? '',
      location: LatLng(
        double.tryParse(json['latitude']?.toString() ?? '0') ?? 0,
        double.tryParse(json['longitude']?.toString() ?? '0') ?? 0,
      ),
      jobType: json['job_type'],
      scheduledTime: json['scheduled_time'] != null
          ? DateTime.tryParse(json['scheduled_time'])
          : null,
      notes: json['notes'],
      estimatedDurationMinutes: json['estimated_duration'],
    );
  }

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'workiz_serial_id': workizSerialId,
    'customer_name': customerName,
    'address': address,
    'latitude': location.latitude,
    'longitude': location.longitude,
    'job_type': jobType,
    'scheduled_time': scheduledTime?.toIso8601String(),
    'notes': notes,
    'estimated_duration': estimatedDurationMinutes,
  };
}

/// Simple LatLng class
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}
