import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_config.dart';

/// Service for managing website variables (contact info, social media, etc.)
class WebManagementService {
  static const String _baseUrl = ApiConfig.websiteVariables;
  static const String _sitesUrl = ApiConfig.wordpressSites;

  /// Get list of all WordPress sites with their variable status
  static Future<Map<String, dynamic>> listSites() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl?action=list'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get variables for a specific site by ID
  static Future<Map<String, dynamic>> getVariables(int siteId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=get&site_id=$siteId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Save variables for a site
  static Future<Map<String, dynamic>> saveVariables(
    int siteId,
    Map<String, dynamic> variables,
  ) async {
    try {
      final body = {'site_id': siteId, ...variables};

      final response = await http.post(
        Uri.parse('$_baseUrl?action=save'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get social media defaults for a group
  static Future<Map<String, dynamic>> getGroupSocialDefaults(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$_sitesUrl?action=get_group_social&group_id=$groupId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Save social media defaults for a group
  static Future<Map<String, dynamic>> saveGroupSocialDefaults(
    int groupId,
    GroupSocialDefaults defaults,
  ) async {
    try {
      final body = {
        'group_id': groupId,
        ...defaults.toJson(),
      };

      final response = await http.post(
        Uri.parse('$_sitesUrl?action=save_group_social'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

/// Model for website variables
class WebsiteVariables {
  final int? id;
  final int siteId;

  // Business Info
  String? businessName;
  String? cityName;      // City for geo-targeting (e.g., "Los Angeles")
  String? locationName;  // State for geo-targeting (e.g., "California")
  String? tagline;
  String? googleMapsUrl; // Google Maps embed/link URL

  // Contact Info
  String? phonePrimary;
  String? phoneSecondary;
  String? emailPrimary;
  String? emailSecondary;

  // Address Info
  String? addressLine1;
  String? addressLine2;
  String? city;
  String? state;
  String? zip;
  String? country;

  // Social Media
  String? facebookUrl;
  String? instagramUrl;
  String? youtubeUrl;
  String? twitterUrl;
  String? linkedinUrl;
  String? tiktokUrl;
  String? yelpUrl;
  String? googleBusinessUrl;
  String? pinterestUrl;
  String? bbbUrl;
  String? nextdoorUrl;
  String? houzzUrl;
  String? angiUrl;
  String? thumbtackUrl;

  // Operating Hours
  Map<String, String>? operatingHours;

  WebsiteVariables({
    this.id,
    required this.siteId,
    this.businessName,
    this.cityName,
    this.locationName,
    this.tagline,
    this.googleMapsUrl,
    this.phonePrimary,
    this.phoneSecondary,
    this.emailPrimary,
    this.emailSecondary,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.zip,
    this.country = 'USA',
    this.facebookUrl,
    this.instagramUrl,
    this.youtubeUrl,
    this.twitterUrl,
    this.linkedinUrl,
    this.tiktokUrl,
    this.yelpUrl,
    this.googleBusinessUrl,
    this.pinterestUrl,
    this.bbbUrl,
    this.nextdoorUrl,
    this.houzzUrl,
    this.angiUrl,
    this.thumbtackUrl,
    this.operatingHours,
  });

  factory WebsiteVariables.fromJson(Map<String, dynamic> json, int siteId) {
    Map<String, String>? hours;
    if (json['operating_hours'] != null) {
      if (json['operating_hours'] is Map) {
        hours = Map<String, String>.from(json['operating_hours']);
      }
    }

    return WebsiteVariables(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      siteId: siteId,
      businessName: json['business_name'],
      cityName: json['city_name'],
      locationName: json['location_name'],
      tagline: json['tagline'],
      googleMapsUrl: json['google_maps_url'],
      phonePrimary: json['phone_primary'],
      phoneSecondary: json['phone_secondary'],
      emailPrimary: json['email_primary'],
      emailSecondary: json['email_secondary'],
      addressLine1: json['address_line1'],
      addressLine2: json['address_line2'],
      city: json['city'],
      state: json['state'],
      zip: json['zip'],
      country: json['country'] ?? 'USA',
      facebookUrl: json['facebook_url'],
      instagramUrl: json['instagram_url'],
      youtubeUrl: json['youtube_url'],
      twitterUrl: json['twitter_url'],
      linkedinUrl: json['linkedin_url'],
      tiktokUrl: json['tiktok_url'],
      yelpUrl: json['yelp_url'],
      googleBusinessUrl: json['google_business_url'],
      pinterestUrl: json['pinterest_url'],
      bbbUrl: json['bbb_url'],
      nextdoorUrl: json['nextdoor_url'],
      houzzUrl: json['houzz_url'],
      angiUrl: json['angi_url'],
      thumbtackUrl: json['thumbtack_url'],
      operatingHours: hours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'business_name': businessName,
      'city_name': cityName,
      'location_name': locationName,
      'tagline': tagline,
      'google_maps_url': googleMapsUrl,
      'phone_primary': phonePrimary,
      'phone_secondary': phoneSecondary,
      'email_primary': emailPrimary,
      'email_secondary': emailSecondary,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'facebook_url': facebookUrl,
      'instagram_url': instagramUrl,
      'youtube_url': youtubeUrl,
      'twitter_url': twitterUrl,
      'linkedin_url': linkedinUrl,
      'tiktok_url': tiktokUrl,
      'yelp_url': yelpUrl,
      'google_business_url': googleBusinessUrl,
      'pinterest_url': pinterestUrl,
      'bbb_url': bbbUrl,
      'nextdoor_url': nextdoorUrl,
      'houzz_url': houzzUrl,
      'angi_url': angiUrl,
      'thumbtack_url': thumbtackUrl,
      'operating_hours': operatingHours,
    };
  }

  /// Create empty variables for a site
  factory WebsiteVariables.empty(int siteId) {
    return WebsiteVariables(
      siteId: siteId,
      country: 'USA',
      operatingHours: {
        'mon': '',
        'tue': '',
        'wed': '',
        'thu': '',
        'fri': '',
        'sat': '',
        'sun': '',
      },
    );
  }
}

/// Model for group social media defaults
class GroupSocialDefaults {
  final int? id;
  final int groupId;

  // Social Media URLs
  String? facebookUrl;
  String? instagramUrl;
  String? youtubeUrl;
  String? twitterUrl;
  String? linkedinUrl;
  String? tiktokUrl;
  String? yelpUrl;
  String? googleBusinessUrl;

  // Enabled flags
  bool facebookEnabled;
  bool instagramEnabled;
  bool youtubeEnabled;
  bool twitterEnabled;
  bool linkedinEnabled;
  bool tiktokEnabled;
  bool yelpEnabled;
  bool googleBusinessEnabled;

  GroupSocialDefaults({
    this.id,
    required this.groupId,
    this.facebookUrl,
    this.instagramUrl,
    this.youtubeUrl,
    this.twitterUrl,
    this.linkedinUrl,
    this.tiktokUrl,
    this.yelpUrl,
    this.googleBusinessUrl,
    this.facebookEnabled = true,
    this.instagramEnabled = true,
    this.youtubeEnabled = true,
    this.twitterEnabled = true,
    this.linkedinEnabled = true,
    this.tiktokEnabled = true,
    this.yelpEnabled = true,
    this.googleBusinessEnabled = true,
  });

  factory GroupSocialDefaults.fromJson(Map<String, dynamic> json, int groupId) {
    return GroupSocialDefaults(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      groupId: groupId,
      facebookUrl: json['facebook_url'],
      instagramUrl: json['instagram_url'],
      youtubeUrl: json['youtube_url'],
      twitterUrl: json['twitter_url'],
      linkedinUrl: json['linkedin_url'],
      tiktokUrl: json['tiktok_url'],
      yelpUrl: json['yelp_url'],
      googleBusinessUrl: json['google_business_url'],
      facebookEnabled: _parseBool(json['facebook_enabled']),
      instagramEnabled: _parseBool(json['instagram_enabled']),
      youtubeEnabled: _parseBool(json['youtube_enabled']),
      twitterEnabled: _parseBool(json['twitter_enabled']),
      linkedinEnabled: _parseBool(json['linkedin_enabled']),
      tiktokEnabled: _parseBool(json['tiktok_enabled']),
      yelpEnabled: _parseBool(json['yelp_enabled']),
      googleBusinessEnabled: _parseBool(json['google_business_enabled']),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'facebook_url': facebookUrl,
      'facebook_enabled': facebookEnabled ? 1 : 0,
      'instagram_url': instagramUrl,
      'instagram_enabled': instagramEnabled ? 1 : 0,
      'youtube_url': youtubeUrl,
      'youtube_enabled': youtubeEnabled ? 1 : 0,
      'twitter_url': twitterUrl,
      'twitter_enabled': twitterEnabled ? 1 : 0,
      'linkedin_url': linkedinUrl,
      'linkedin_enabled': linkedinEnabled ? 1 : 0,
      'tiktok_url': tiktokUrl,
      'tiktok_enabled': tiktokEnabled ? 1 : 0,
      'yelp_url': yelpUrl,
      'yelp_enabled': yelpEnabled ? 1 : 0,
      'google_business_url': googleBusinessUrl,
      'google_business_enabled': googleBusinessEnabled ? 1 : 0,
    };
  }

  /// Create empty defaults for a group
  factory GroupSocialDefaults.empty(int groupId) {
    return GroupSocialDefaults(groupId: groupId);
  }

  /// Get URL for a specific platform key
  String? getUrl(String key) {
    switch (key) {
      case 'facebook_url': return facebookUrl;
      case 'instagram_url': return instagramUrl;
      case 'youtube_url': return youtubeUrl;
      case 'twitter_url': return twitterUrl;
      case 'linkedin_url': return linkedinUrl;
      case 'tiktok_url': return tiktokUrl;
      case 'yelp_url': return yelpUrl;
      case 'google_business_url': return googleBusinessUrl;
      default: return null;
    }
  }

  /// Get enabled flag for a specific platform key
  bool isEnabled(String key) {
    switch (key) {
      case 'facebook_url': return facebookEnabled;
      case 'instagram_url': return instagramEnabled;
      case 'youtube_url': return youtubeEnabled;
      case 'twitter_url': return twitterEnabled;
      case 'linkedin_url': return linkedinEnabled;
      case 'tiktok_url': return tiktokEnabled;
      case 'yelp_url': return yelpEnabled;
      case 'google_business_url': return googleBusinessEnabled;
      default: return true;
    }
  }
}
