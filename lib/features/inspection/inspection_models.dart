// Inspection Models
//
// Data models for the inspection system.

class Inspection {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String address;
  final String? state;
  final String? zipCode;
  final String chimneyType;
  final String condition;
  final String? description;
  final String issues;
  final String recommendations;
  final List<InspectionPhoto> photos;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? customerName;
  final String? customerPhone;

  // Job fields
  final String jobCategory;
  final String jobType;
  final String completionStatus; // 'completed', 'incomplete', 'follow_up_needed'
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? localSubmitTime;
  final bool discountUsed;

  Inspection({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    required this.address,
    this.state,
    this.zipCode,
    required this.chimneyType,
    required this.condition,
    this.description,
    required this.issues,
    required this.recommendations,
    required this.photos,
    required this.createdAt,
    this.updatedAt,
    this.customerName,
    this.customerPhone,
    this.jobCategory = '',
    this.jobType = '',
    this.completionStatus = 'completed',
    this.startTime,
    this.endTime,
    this.localSubmitTime,
    this.discountUsed = false,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      address: json['address'] ?? '',
      state: json['state'],
      zipCode: json['zip_code'],
      chimneyType: json['chimney_type'] ?? '',
      condition: json['condition'] ?? '',
      description: json['description'],
      issues: json['issues'] ?? '',
      recommendations: json['recommendations'] ?? '',
      photos: (json['photos'] as List?)
          ?.map((p) => InspectionPhoto.fromJson(p))
          .toList() ?? [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      jobCategory: json['job_category'] ?? '',
      jobType: json['job_type'] ?? '',
      completionStatus: json['completion_status'] ?? 'completed',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
      localSubmitTime: json['local_submit_time'] != null
          ? DateTime.tryParse(json['local_submit_time'])
          : null,
      discountUsed: json['discount_used'] == true || json['discount_used'] == 1 || json['discount_used'] == '1',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': firstName,
    'last_name': lastName,
    'address': address,
    'state': state,
    'zip_code': zipCode,
    'chimney_type': chimneyType,
    'condition': condition,
    'description': description,
    'issues': issues,
    'recommendations': recommendations,
    'photos': photos.map((p) => p.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'job_category': jobCategory,
    'job_type': jobType,
    'completion_status': completionStatus,
    'start_time': startTime?.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'local_submit_time': localSubmitTime?.toIso8601String(),
    'discount_used': discountUsed,
  };

  String get displayName {
    if (firstName?.isNotEmpty == true || lastName?.isNotEmpty == true) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return username;
  }

  String get customerDisplayName => customerName?.isNotEmpty == true
      ? customerName!
      : address;

  String get fullAddress {
    final parts = <String>[address];
    if (state?.isNotEmpty == true) parts.add(state!);
    if (zipCode?.isNotEmpty == true) parts.add(zipCode!);
    return parts.join(', ');
  }

  int get photoCount => photos.length;

  String get completionStatusDisplay {
    switch (completionStatus) {
      case 'completed':
        return 'Completed';
      case 'incomplete':
        return 'Incomplete';
      case 'follow_up_needed':
        return 'Follow-up Required';
      default:
        return completionStatus;
    }
  }

  Duration? get jobDuration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }
}

class InspectionPhoto {
  final int id;
  final String url;
  final String? caption;
  final String? filename;
  final DateTime createdAt;

  InspectionPhoto({
    required this.id,
    required this.url,
    this.caption,
    this.filename,
    required this.createdAt,
  });

  factory InspectionPhoto.fromJson(Map<String, dynamic> json) {
    return InspectionPhoto(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      url: json['url'] ?? '',
      caption: json['caption'],
      filename: json['filename'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'caption': caption,
    'filename': filename,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Photo to be uploaded (before it has an ID/URL)
class PendingPhoto {
  final String base64Data;
  final String filename;
  final String? caption;

  PendingPhoto({
    required this.base64Data,
    required this.filename,
    this.caption,
  });

  Map<String, dynamic> toJson() => {
    'data': base64Data,
    'filename': filename,
    'caption': caption,
  };
}

/// Chimney types available for selection
class ChimneyTypes {
  static const List<String> all = [
    'Brick',
    'Metal',
    'Prefab',
    'Stone',
    'Stucco',
    'Other',
  ];
}

/// Condition ratings
class ConditionRatings {
  static const List<String> all = [
    'Good',
    'Fair',
    'Poor',
    'Critical',
  ];

  static String getDescription(String condition) {
    switch (condition) {
      case 'Good':
        return 'No significant issues found';
      case 'Fair':
        return 'Minor issues, maintenance recommended';
      case 'Poor':
        return 'Significant issues, repairs needed';
      case 'Critical':
        return 'Immediate attention required';
      default:
        return '';
    }
  }
}

/// Job completion status options
class CompletionStatus {
  static const String completed = 'completed';
  static const String incomplete = 'incomplete';
  static const String followUpNeeded = 'follow_up_needed';

  static const List<String> all = [completed, incomplete, followUpNeeded];

  static String getDisplay(String status) {
    switch (status) {
      case completed:
        return 'Completed';
      case incomplete:
        return 'Incomplete';
      case followUpNeeded:
        return 'Follow-up Required';
      default:
        return status;
    }
  }
}

/// Job categories and their types
class JobCategories {
  static const Map<String, List<String>> categories = {
    'Inspection': [
      'Inspection Level 1',
      'Inspection Level 2',
      'Inspection Level 3',
      'Chimney Maintenance',
      'Pellet Stove Inspection',
    ],
    'Cleaning': [
      'Chimney Animal Removal',
      'Chimney Deep Cleaning',
      'Chimney Nest Removal',
      'Chimney Sweep',
      'Dryer Vent Cleaning',
      'Smoke Chamber Clean',
    ],
    'Repair': [
      'Chimney Bricks Repair',
      'Chimney Cap Repair',
      'Chimney Crown Repair',
      'Chimney Damper Repair',
      'Chimney Flashing',
      'Chimney Flue Repair',
      'Chimney Framing Repair',
      'Chimney Liner Repair',
      'Chimney Masonry Repair',
      'Chimney Repair',
      'Chimney Siding Repair',
      'Chimney Tuckpointing',
      'Downdraft Repair',
      'Electric Fireplace Repair',
      'Fireplace Gas Valve Repair',
      'Fireplace Masonry Repair',
      'Fireplace Panels Repair',
      'Gas Fireplace Repair',
      'Pellet Stove Repair',
      'Smoke Chamber Repair',
      'Waterproofing Bricks',
    ],
    'Installation': [
      'Chimney Cap Installation',
      'Chimney Cricket Installation',
      'Chimney Fan Installation',
      'Chimney Flue Installation',
      'Chimney Liner Installation',
      'Chimney Vent Installation',
      'Electric Fireplace Installation',
      'Fireplace Gas Burner Installation',
      'Fireplace Installation',
      'Flexible Chimney Liner Installation',
      'Pellet Stove Installation',
      'Pilot Light Installation',
      'Spark Arrestor Installation',
      'Ventless Gas Logs Installation',
      'Vented Gas Logs Installation',
    ],
    'Replacement': [
      'Chimney Chase Covering',
      'Chimney Siding Replace',
      'Exterior Wood Replacement',
      'Fireplace Gas Valve Replace',
      'Fireplace Panels Replace',
      'Glass Door Fireplace',
      'Pilot Assembly Replacement',
      'Remote Control for a Pilot Light',
    ],
    'Construction': [
      'Chimney Construction',
      'Chimney Framing Rebuild',
      'Chimney Rebuild',
      'Chimney Restoration',
      'Smoke Chamber Rebuild',
    ],
  };

  static List<String> get allCategories => categories.keys.toList();

  static List<String> getTypesForCategory(String category) {
    return categories[category] ?? [];
  }
}

/// US States for address selection
class USStates {
  static const List<String> all = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
    'DC',
  ];

  static const Map<String, String> names = {
    'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
    'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
    'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii', 'ID': 'Idaho',
    'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
    'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
    'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
    'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
    'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico', 'NY': 'New York',
    'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio', 'OK': 'Oklahoma',
    'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
    'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
    'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
    'WI': 'Wisconsin', 'WY': 'Wyoming', 'DC': 'District of Columbia',
  };

  static String getName(String abbr) => names[abbr] ?? abbr;
}
