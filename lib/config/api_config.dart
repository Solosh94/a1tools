/// Centralized API configuration for A1 Tools
/// All API endpoints and base URLs should be defined here
library;

class ApiConfig {
  ApiConfig._();

  // ============================================
  // API VERSIONING
  // ============================================

  /// Current API version used by this client
  static const String apiVersion = '1.0';

  /// Minimum API version this client supports
  static const String minApiVersion = '1.0';

  /// Header name for sending client API version
  static const String apiVersionHeader = 'X-API-Version';

  /// Header name for requesting specific API version
  static const String acceptVersionHeader = 'Accept-Version';

  /// Get default headers including API version
  static Map<String, String> get defaultHeaders => {
    apiVersionHeader: apiVersion,
    acceptVersionHeader: apiVersion,
    'X-Client-Platform': 'flutter',
  };

  // ============================================
  // BASE URLS
  // ============================================

  /// Main tools server base URL
  static const String baseUrl = 'https://tools.a-1chimney.com';

  /// Main API base path (unversioned - legacy)
  static const String apiBase = '$baseUrl/api';

  /// Versioned API base paths (for future use)
  static const String apiV1Base = '$baseUrl/api/v1';
  static const String apiV2Base = '$baseUrl/api/v2';

  /// WordPress REST API base
  static const String wpApiBase = '$baseUrl/wp-json/a1-tools/v1';

  /// N8N webhook base URL
  static const String n8nBase = 'https://a1tools.app.n8n.cloud/webhook';

  /// Get versioned endpoint URL
  /// [endpoint] - The endpoint path (e.g., 'users.php')
  /// [version] - API version (defaults to current version)
  static String versioned(String endpoint, {String? version}) {
    final v = version ?? apiVersion;
    return switch (v) {
      '1.0' => '$apiBase/$endpoint', // v1 uses existing endpoints
      '2.0' => '$apiV2Base/$endpoint',
      _ => '$apiBase/$endpoint',
    };
  }

  // ============================================
  // AUTHENTICATION
  // ============================================

  static const String auth = '$baseUrl/a1tools_auth.php';
  static const String passwordReset = '$apiBase/password_reset.php';
  static const String userManagement = '$apiBase/user_management.php';
  static const String users = '$apiBase/users.php';

  // ============================================
  // ALERTS & NOTIFICATIONS
  // ============================================

  static const String alerts = '$apiBase/alerts.php';
  static const String alertsHeartbeat = '$wpApiBase/alerts/heartbeat';
  static const String fcmConfig = '$apiBase/fcm_config.php';
  static const String pushNotifications = '$apiBase/push_notifications.php';

  // ============================================
  // CHAT & MESSAGING
  // ============================================

  static const String chatMessages = '$apiBase/chat_messages.php';
  static const String chatGroups = '$apiBase/chat_groups.php';

  // ============================================
  // PROFILE
  // ============================================

  static const String profilePicture = '$apiBase/profile/picture.php';

  // ============================================
  // INSPECTIONS
  // ============================================

  static const String inspections = '$apiBase/inspections.php';
  static const String inspectionReports = '$apiBase/inspection_reports.php';
  static const String inspectionWorkflow = '$apiBase/inspection_workflow.php';
  static const String inspectionDrafts = '$apiBase/inspection_drafts.php';

  // ============================================
  // TRAINING
  // ============================================

  static const String trainingTests = '$apiBase/training_tests.php';
  static const String trainingProgress = '$apiBase/training_progress.php';
  static const String trainingResults = '$apiBase/training_results.php';
  static const String trainingQuestions = '$apiBase/training_questions.php';
  static const String trainingDashboard = '$apiBase/training_dashboard.php';
  static const String trainingKnowledgeBase = '$apiBase/training_knowledge_base.php';
  static const String kbProgress = '$apiBase/kb_progress.php';

  // ============================================
  // TIME CLOCK & SCHEDULING
  // ============================================

  /// Time clock endpoint - new route to force legacy app updates
  static const String timeClock = '$apiBase/clocker/time_clock.php';
  static const String weeklyTimeReport = '$apiBase/weekly_time_report.php';
  static const String officeMap = '$apiBase/office_map.php';
  static const String compliance = '$apiBase/compliance.php';
  static const String payroll = '$apiBase/payroll.php';
  static const String lockScreenExceptions = '$apiBase/lock_screen_exceptions.php';
  static const String privacyExclusions = '$apiBase/privacy_exclusions.php';

  // ============================================
  // HR
  // ============================================

  static const String hrEmployees = '$apiBase/hr_employees.php';
  static const String hr = hrEmployees; // Legacy alias

  // ============================================
  // METRICS & MONITORING
  // ============================================

  static const String metricsAll = '$apiBase/metrics_all.php';
  static const String metricsStore = '$apiBase/metrics_store.php';
  static const String metricsComputer = '$apiBase/metrics_computer.php';
  static const String metricsSystemMetrics = '$apiBase/metrics_system_metrics.php';
  static const String systemMetrics = '$apiBase/system_metrics.php';
  static const String remoteMonitoring = '$apiBase/remote_monitoring.php';
  static const String screenshotGet = remoteMonitoring; // Screenshot functionality in remote_monitoring

  // ============================================
  // MARKETING
  // ============================================

  static const String mailchimpIntegration = '$apiBase/mailchimp_integration.php';
  static const String twilioIntegration = '$apiBase/twilio_integration.php';
  static const String blogPosts = '$apiBase/blog_posts.php';

  // ============================================
  // INTEGRATIONS
  // ============================================

  static const String workizLocations = '$apiBase/workiz_locations.php';
  static const String workiz = '$apiBase/workiz.php';
  static const String wordpressSites = '$apiBase/wordpress_sites.php';
  static const String websiteVariables = '$apiBase/website_variables.php';

  // ============================================
  // AUDIT LOGGING
  // ============================================

  static const String auditLog = '$apiBase/audit_log.php';

  // ============================================
  // DATA EXPORT (GDPR)
  // ============================================

  static const String dataExport = '$apiBase/data_export.php';

  // ============================================
  // CONFIGURATION
  // ============================================

  static const String logoConfig = '$apiBase/logo_config.php';
  static const String routeConfig = '$apiBase/route_config.php';
  static const String smtpConfig = '$apiBase/smtp_config.php';
  static const String roleAccess = '$apiBase/role_access.php';
  static const String vmSettings = '$apiBase/vm_settings.php';

  // ============================================
  // ROUTES & MAPS
  // ============================================

  static const String routeOptimization = '$apiBase/route_optimization.php';

  // ============================================
  // SUNDAY (Kanban Boards)
  // ============================================

  static const String sundayNotifications = '$apiBase/sunday/notifications.php';

  // ============================================
  // SUGGESTIONS
  // ============================================

  static const String suggestions = '$apiBase/suggestions.php';

  // ============================================
  // SIGNATURES
  // ============================================

  static const String signatures = '$apiBase/signatures.php';

  // ============================================
  // APP UPDATES
  // ============================================

  static const String appUpdate = '$apiBase/app_update.php';
  static const String latestVersion = '$baseUrl/downloads/latest.json';
  static const String installerBase = '$baseUrl/a1-tools-installer/';
  static const String downloadsBase = '$baseUrl/downloads';

  /// Generate download URL for a specific version
  static String installerDownload(String version) =>
      '$downloadsBase/A1-Tools-Setup-$version.exe';

  // ============================================
  // EXTERNAL SERVICES
  // ============================================

  /// IP lookup service
  static const String ipLookup = 'https://api.ipify.org';

  /// App Store ID for iOS
  static const String appStoreId = '6738715498';
  static const String appStoreUrl = 'https://apps.apple.com/us/app/a1-tools/id$appStoreId';
  static const String appStoreLookup = 'https://itunes.apple.com/lookup?id=$appStoreId&country=us';

  // ============================================
  // GOOGLE APIS
  // ============================================

  static const String googleMapsDistanceMatrix = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String googleMapsDirections = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String googleMapsGeocode = 'https://maps.googleapis.com/maps/api/geocode/json';

  /// Generate Google Maps directions URL
  static String googleMapsDirectionsUrl({
    required String origin,
    required String destination,
    String? waypoints,
  }) {
    final base = 'https://www.google.com/maps/dir/?api=1'
        '&origin=${Uri.encodeComponent(origin)}'
        '&destination=${Uri.encodeComponent(destination)}'
        '&travelmode=driving';
    if (waypoints != null && waypoints.isNotEmpty) {
      return '$base&waypoints=$waypoints';
    }
    return base;
  }

  /// Generate Google Maps search URL
  static String googleMapsSearch(String query) =>
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';

  // ============================================
  // VIDEO PLATFORMS
  // ============================================

  /// YouTube thumbnail URL
  static String youtubeThumbnail(String videoId) =>
      'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

  /// YouTube embed URL
  static String youtubeEmbed(String videoId) =>
      'https://www.youtube.com/embed/$videoId?autoplay=1&rel=0&modestbranding=1';

  /// YouTube watch URL
  static String youtubeWatch(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  /// Vimeo player embed URL
  static String vimeoEmbed(String videoId) =>
      'https://player.vimeo.com/video/$videoId?autoplay=1&title=0&byline=0&portrait=0';

  /// Vimeo watch URL
  static String vimeoWatch(String videoId) =>
      'https://vimeo.com/$videoId';

  // ============================================
  // N8N WEBHOOKS
  // ============================================

  static const String n8nDispatcherSummary = '$n8nBase/dispatcher-summary';
  static const String n8nRouteSuggest = '$n8nBase/route-suggest';

  // ============================================
  // EXTERNAL LINKS
  // ============================================

  static const String webView2Download = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703';
  static const String whatsAppWeb = 'https://web.whatsapp.com/send';

  /// Generate WhatsApp share URL
  static String whatsAppShare(String text) =>
      '$whatsAppWeb?text=${Uri.encodeComponent(text)}';

  // ============================================
  // WORKIZ
  // ============================================

  static const String workizLogin = 'https://app.workiz.com/login/';
}
