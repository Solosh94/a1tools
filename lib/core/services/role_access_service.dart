// Role Access Service
//
// Manages role-based feature accessibility settings.
// Allows admins to configure which features are accessible by which roles.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Represents a feature that can have role-based access control
class FeatureAccess {
  final String featureId;
  final String featureName;
  final String description;
  final String category;
  final List<String> allowedRoles;
  final bool isSystemFeature; // System features cannot be fully disabled

  const FeatureAccess({
    required this.featureId,
    required this.featureName,
    required this.description,
    required this.category,
    required this.allowedRoles,
    this.isSystemFeature = false,
  });

  factory FeatureAccess.fromJson(Map<String, dynamic> json) {
    return FeatureAccess(
      featureId: json['feature_id'] as String,
      featureName: json['feature_name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      allowedRoles: List<String>.from(json['allowed_roles'] ?? []),
      isSystemFeature: json['is_system_feature'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'feature_id': featureId,
    'feature_name': featureName,
    'description': description,
    'category': category,
    'allowed_roles': allowedRoles,
    'is_system_feature': isSystemFeature,
  };

  FeatureAccess copyWith({List<String>? allowedRoles}) {
    return FeatureAccess(
      featureId: featureId,
      featureName: featureName,
      description: description,
      category: category,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      isSystemFeature: isSystemFeature,
    );
  }
}

/// All available roles in the system
class RoleDefinition {
  static const List<String> allRoles = [
    'developer',
    'administrator',
    'management',
    'dispatcher',
    'remote_dispatcher',
    'technician',
    'marketing',
  ];

  static String formatRoleName(String role) {
    switch (role) {
      case 'developer': return 'Developer';
      case 'administrator': return 'Administrator';
      case 'management': return 'Management';
      case 'dispatcher': return 'Dispatcher';
      case 'remote_dispatcher': return 'Remote Dispatcher';
      case 'technician': return 'Technician';
      case 'marketing': return 'Marketing';
      default: return role;
    }
  }
}

/// Default feature definitions (used when API doesn't return data)
class DefaultFeatures {
  static List<FeatureAccess> get all => [
    // Home Screen Features
    const FeatureAccess(
      featureId: 'guidelines',
      featureName: 'Guidelines',
      description: 'Company policies & procedures',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'dispatcher', 'remote_dispatcher', 'technician', 'marketing'],
      isSystemFeature: true,
    ),
    const FeatureAccess(
      featureId: 'inspection',
      featureName: 'Inspection',
      description: 'Submit inspection reports',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'technician'],
    ),
    const FeatureAccess(
      featureId: 'inventory_scanner',
      featureName: 'Inventory Scanner',
      description: 'Scan & manage inventory items',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'technician'],
    ),
    const FeatureAccess(
      featureId: 'management',
      featureName: 'Management',
      description: 'Admin tools & analytics',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),
    const FeatureAccess(
      featureId: 'marketing_tools',
      featureName: 'Marketing Tools',
      description: 'Image editing, blog creator & more',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'marketing'],
    ),
    const FeatureAccess(
      featureId: 'messages',
      featureName: 'Messages',
      description: 'Send & receive alerts',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'dispatcher', 'remote_dispatcher'],
    ),
    const FeatureAccess(
      featureId: 'schedule',
      featureName: 'Schedule',
      description: 'Calendar, hours & time tracking',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'dispatcher', 'remote_dispatcher', 'technician', 'marketing'],
      isSystemFeature: true,
    ),
    const FeatureAccess(
      featureId: 'training',
      featureName: 'Training',
      description: 'Courses & certification tests',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'dispatcher', 'remote_dispatcher', 'technician', 'marketing'],
      isSystemFeature: true,
    ),
    const FeatureAccess(
      featureId: 'sunday',
      featureName: 'Sunday',
      description: 'Boards, leads & job tracking',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'dispatcher', 'remote_dispatcher', 'technician', 'marketing'],
    ),
    const FeatureAccess(
      featureId: 'route_planner',
      featureName: 'Route Planner',
      description: 'Optimize daily route (mobile)',
      category: 'Home',
      allowedRoles: ['developer', 'technician'],
    ),
    const FeatureAccess(
      featureId: 'suggestions',
      featureName: 'Suggestions',
      description: 'Share ideas for improvements',
      category: 'Home',
      allowedRoles: ['developer', 'administrator', 'management', 'dispatcher', 'remote_dispatcher', 'technician', 'marketing'],
      isSystemFeature: true,
    ),

    // Management - Administration (All roles: management, administrator, developer)
    const FeatureAccess(
      featureId: 'human_resources',
      featureName: 'Human Resources',
      description: 'Employee database & documents',
      category: 'Administration',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),
    const FeatureAccess(
      featureId: 'authenticator',
      featureName: 'Authenticator',
      description: 'Security codes for sensitive operations',
      category: 'Administration',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),
    const FeatureAccess(
      featureId: 'time_records',
      featureName: 'Time Records',
      description: 'View clock in/out records',
      category: 'Administration',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),
    const FeatureAccess(
      featureId: 'office_map',
      featureName: 'Office Map',
      description: 'View staff locations & status',
      category: 'Administration',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),
    const FeatureAccess(
      featureId: 'training_dashboard',
      featureName: 'Training Dashboard',
      description: 'View user progress & results',
      category: 'Administration',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),

    // Management - Sunday (Administrator, Developer only)
    const FeatureAccess(
      featureId: 'sunday_boards',
      featureName: 'Boards Management',
      description: 'Manage Sunday boards',
      category: 'Sunday',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'sunday_templates',
      featureName: 'Templates Management',
      description: 'Manage board templates',
      category: 'Sunday',
      allowedRoles: ['developer', 'administrator'],
    ),

    // Management - Training (All roles: management, administrator, developer)
    const FeatureAccess(
      featureId: 'study_guide_editor',
      featureName: 'Study Guide Editor',
      description: 'Create & manage training content',
      category: 'Training Management',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),
    const FeatureAccess(
      featureId: 'test_editor',
      featureName: 'Test Editor',
      description: 'Create & manage training tests',
      category: 'Training Management',
      allowedRoles: ['developer', 'administrator', 'management'],
    ),

    // Management - Metrics (Administrator, Developer only)
    const FeatureAccess(
      featureId: 'analytics',
      featureName: 'Analytics',
      description: 'Reports & statistics',
      category: 'Metrics',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'compliance_system',
      featureName: 'Compliance System',
      description: 'Monitor heartbeats & auto clock-out',
      category: 'Metrics',
      allowedRoles: ['developer', 'administrator'],
    ),

    // Management - App Settings (Administrator, Developer only)
    const FeatureAccess(
      featureId: 'lock_screen_exceptions',
      featureName: 'Lock Screen Exceptions',
      description: 'Remote workers & work-from-home',
      category: 'App Management',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'minimum_version',
      featureName: 'Minimum Version',
      description: 'Block outdated app versions',
      category: 'App Management',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'privacy_exclusions',
      featureName: 'Privacy Exclusions',
      description: 'Hide programs from monitoring',
      category: 'App Management',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'push_update',
      featureName: 'Push App Update',
      description: 'Deploy updates to all clients',
      category: 'App Management',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'review_suggestions',
      featureName: 'Review Suggestions',
      description: 'View & manage user suggestions',
      category: 'App Management',
      allowedRoles: ['developer', 'administrator'],
    ),
    const FeatureAccess(
      featureId: 'role_accessibility',
      featureName: 'Role Accessibility',
      description: 'Manage feature access by role',
      category: 'App Management',
      allowedRoles: ['developer', 'administrator'],
    ),

    // Management - General Settings (Developer only)
    const FeatureAccess(
      featureId: 'pdf_logo_config',
      featureName: 'PDF Logo Configuration',
      description: 'Configure logo for inspection reports',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'user_management',
      featureName: 'User Management',
      description: 'Create & manage users',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'fcm_config',
      featureName: 'FCM (Push Notifications)',
      description: 'Configure Firebase Cloud Messaging',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'google_maps_api',
      featureName: 'Google Maps API',
      description: 'Configure route optimization',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'mailchimp',
      featureName: 'Mailchimp',
      description: 'Email marketing integration',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'smtp',
      featureName: 'SMTP',
      description: 'Email server settings',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'twilio',
      featureName: 'Twilio',
      description: 'SMS messaging integration',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'wordpress',
      featureName: 'WordPress',
      description: 'Blog site credentials',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
    const FeatureAccess(
      featureId: 'workiz',
      featureName: 'Workiz',
      description: 'Job management integration',
      category: 'General Settings',
      allowedRoles: ['developer'],
    ),
  ];
}

/// Service for managing role-based feature access
class RoleAccessService {
  RoleAccessService._();
  static final RoleAccessService instance = RoleAccessService._();

  static const String _endpoint = ApiConfig.roleAccess;

  /// Fetch all feature access settings from the server
  Future<List<FeatureAccess>> getFeatureAccessList() async {
    try {
      final response = await http.get(
        Uri.parse('$_endpoint?action=list'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['features'] != null) {
          return (data['features'] as List)
              .map((f) => FeatureAccess.fromJson(f))
              .toList();
        }
      }
    } catch (e) {
      // Fall back to defaults on error
    }

    // Return defaults if API fails or doesn't exist yet
    return DefaultFeatures.all;
  }

  /// Update access settings for a specific feature
  Future<bool> updateFeatureAccess({
    required String featureId,
    required List<String> allowedRoles,
    required String updatedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'update',
          'feature_id': featureId,
          'allowed_roles': allowedRoles,
          'updated_by': updatedBy,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      // Silently fail
    }
    return false;
  }

  /// Check if a user with a given role can access a feature
  Future<bool> canAccess({
    required String featureId,
    required String role,
  }) async {
    final features = await getFeatureAccessList();
    final feature = features.where((f) => f.featureId == featureId).firstOrNull;

    if (feature == null) return true; // Unknown feature, allow by default

    // Developers always have access
    if (role == 'developer') return true;

    return feature.allowedRoles.contains(role);
  }

  /// Get features grouped by category
  Future<Map<String, List<FeatureAccess>>> getFeaturesByCategory() async {
    final features = await getFeatureAccessList();
    final grouped = <String, List<FeatureAccess>>{};

    for (final feature in features) {
      grouped.putIfAbsent(feature.category, () => []).add(feature);
    }

    return grouped;
  }

  /// Reset all features to default settings
  Future<bool> resetToDefaults({required String updatedBy}) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'reset',
          'updated_by': updatedBy,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      // Silently fail
    }
    return false;
  }
}
