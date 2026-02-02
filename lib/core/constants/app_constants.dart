/// Application-wide constants
///
/// Centralized location for all magic numbers and configuration values
/// used throughout the application. This improves maintainability and
/// makes it easier to adjust values without searching through code.
library;

/// Time-related constants
class TimeConstants {
  TimeConstants._();

  /// Default lookback period for time records (days)
  static const int defaultRecordLookbackDays = 30;

  /// Heartbeat interval for compliance monitoring (seconds)
  static const int heartbeatIntervalSeconds = 20;

  /// Compliance check interval (minutes)
  static const int complianceCheckIntervalMinutes = 2;

  /// Screenshot capture interval (minutes)
  static const int defaultScreenshotIntervalMinutes = 15;

  /// System metrics collection interval (minutes)
  static const int systemMetricsIntervalMinutes = 5;

  /// Alert polling interval (seconds)
  static const int alertPollingIntervalSeconds = 10;

  /// Chat notification check interval (seconds)
  static const int chatNotificationIntervalSeconds = 10;

  /// Unread message count fetch interval (seconds)
  static const int unreadMessageFetchIntervalSeconds = 15;

  /// Sunday notification count fetch interval (seconds)
  static const int sundayNotificationFetchIntervalSeconds = 30;

  /// Clock status check grace period after clock-in (seconds)
  static const int clockInGracePeriodSeconds = 10;

  /// WebSocket reconnect delay (seconds)
  static const int websocketReconnectDelaySeconds = 5;

  /// WebSocket max reconnect delay (seconds)
  static const int websocketMaxReconnectDelaySeconds = 30;

  /// WebSocket ping interval (seconds)
  static const int websocketPingIntervalSeconds = 15;

  /// Command polling interval (milliseconds)
  static const int commandPollingIntervalMs = 500;

  /// Session timeout warning (minutes before expiry)
  static const int sessionTimeoutWarningMinutes = 5;

  /// Auto-logout after inactivity (minutes)
  static const int autoLogoutInactivityMinutes = 30;
}

/// Network-related constants
class NetworkConstants {
  NetworkConstants._();

  /// Default HTTP request timeout (seconds)
  static const int defaultTimeoutSeconds = 30;

  /// Upload timeout for large files (seconds)
  static const int uploadTimeoutSeconds = 120;

  /// Short timeout for quick operations (seconds)
  static const int shortTimeoutSeconds = 10;

  /// Long timeout for slow operations (seconds)
  static const int longTimeoutSeconds = 60;

  /// Maximum retry attempts for failed requests
  static const int maxRetryAttempts = 3;

  /// Initial retry delay (milliseconds)
  static const int initialRetryDelayMs = 500;

  /// Maximum retry delay (seconds)
  static const int maxRetryDelaySeconds = 10;

  /// Retry backoff multiplier
  static const double retryBackoffMultiplier = 2.0;

  /// HTTP status codes that should trigger retry
  static const Set<int> retryStatusCodes = {502, 503, 504, 429};

  // Circuit Breaker Constants

  /// Number of failures before circuit breaker opens
  static const int circuitBreakerFailureThreshold = 5;

  /// Time to wait before testing recovery (seconds)
  static const int circuitBreakerResetTimeoutSeconds = 30;

  /// Successful requests needed to close circuit
  static const int circuitBreakerSuccessThreshold = 2;

  /// HTTP status codes that count as circuit breaker failures
  static const Set<int> circuitBreakerFailureStatusCodes = {500, 502, 503, 504};
}

/// Pagination constants
class PaginationConstants {
  PaginationConstants._();

  /// Default page size for lists
  static const int defaultPageSize = 20;

  /// Maximum page size allowed
  static const int maxPageSize = 100;

  /// Default search results limit
  static const int defaultSearchLimit = 20;
}

/// Validation constants
class ValidationConstants {
  ValidationConstants._();

  /// Maximum address length
  static const int maxAddressLength = 500;

  /// Maximum description length
  static const int maxDescriptionLength = 2000;

  /// Maximum notes length
  static const int maxNotesLength = 5000;

  /// Maximum photos per inspection
  static const int maxPhotosPerInspection = 50;

  /// Maximum file size for uploads (bytes) - 10MB
  static const int maxUploadFileSizeBytes = 10 * 1024 * 1024;

  /// Maximum inspection duration (hours)
  static const int maxInspectionDurationHours = 24;

  /// Minimum password length
  static const int minPasswordLength = 8;

  /// Maximum username length
  static const int maxUsernameLength = 50;

  /// Phone number pattern (US format)
  static const String phoneNumberPattern = r'^\d{10}$|^\d{3}-\d{3}-\d{4}$';

  /// Email pattern
  static const String emailPattern = r'^[\w\.-]+@[\w\.-]+\.\w+$';
}

/// UI constants
class UIConstants {
  UIConstants._();

  /// Default animation duration (milliseconds)
  static const int defaultAnimationDurationMs = 300;

  /// Short animation duration (milliseconds)
  static const int shortAnimationDurationMs = 150;

  /// Long animation duration (milliseconds)
  static const int longAnimationDurationMs = 500;

  /// Snackbar display duration (seconds)
  static const int snackbarDurationSeconds = 4;

  /// Toast display duration (seconds)
  static const int toastDurationSeconds = 2;

  /// Loading indicator debounce (milliseconds)
  static const int loadingDebounceMs = 200;

  /// Maximum items to show before "show more"
  static const int maxItemsBeforeShowMore = 5;

  /// Thumbnail size (pixels)
  static const int thumbnailSize = 100;

  /// Preview image size (pixels)
  static const int previewImageSize = 300;
}

/// Cache constants
class CacheConstants {
  CacheConstants._();

  /// Maximum number of caches in registry
  static const int maxCachesInRegistry = 100;

  /// Very short TTL (seconds)
  static const int veryShortTtlSeconds = 30;

  /// Short TTL (minutes)
  static const int shortTtlMinutes = 1;

  /// Standard TTL (minutes)
  static const int standardTtlMinutes = 5;

  /// Medium TTL (minutes)
  static const int mediumTtlMinutes = 15;

  /// Long TTL (minutes)
  static const int longTtlMinutes = 30;

  /// Very long TTL (hours)
  static const int veryLongTtlHours = 1;

  /// Persistent TTL (hours)
  static const int persistentTtlHours = 24;

  /// Maximum cache memory size (bytes) - 50MB
  static const int maxCacheMemoryBytes = 50 * 1024 * 1024;

  /// Maximum entries per cache (for LRU eviction)
  static const int maxEntriesPerCache = 1000;
}

/// Request pooling and backpressure constants
class RequestPoolConstants {
  RequestPoolConstants._();

  /// Maximum concurrent screenshot uploads
  static const int maxConcurrentScreenshots = 3;

  /// Maximum pending screenshot requests in queue
  static const int maxPendingScreenshots = 10;

  /// Screenshot upload timeout (seconds)
  static const int screenshotUploadTimeoutSeconds = 30;

  /// Maximum concurrent API requests per endpoint
  static const int maxConcurrentRequestsPerEndpoint = 5;

  /// Maximum total concurrent API requests
  static const int maxTotalConcurrentRequests = 20;

  /// Request queue timeout (milliseconds) - how long to wait in queue
  static const int requestQueueTimeoutMs = 30000;
}

/// Debounce and throttle constants
class DebounceConstants {
  DebounceConstants._();

  /// Search input debounce (milliseconds)
  static const int searchDebounceMs = 300;

  /// Form field editing debounce (milliseconds)
  static const int editingDebounceMs = 500;

  /// SEO analysis debounce (milliseconds)
  static const int seoDebounceMs = 300;

  /// Mouse movement throttle (milliseconds)
  static const int mouseThrottleMs = 50;

  /// Sidebar refresh interval (milliseconds)
  static const int sidebarRefreshMs = 500;

  /// Value update debounce (milliseconds)
  static const int valueUpdateDebounceMs = 300;
}

/// Polling interval constants
class PollingConstants {
  PollingConstants._();

  /// VM status polling interval (seconds)
  static const int vmPollingIntervalSeconds = 30;

  /// Audio playback polling (milliseconds)
  static const int audioPollingIntervalMs = 500;

  /// Auto-refresh interval for admin screens (seconds)
  static const int adminAutoRefreshSeconds = 30;
}

/// Role constants
class RoleConstants {
  RoleConstants._();

  /// Roles that require clock in/out
  static const List<String> clockRequiredRoles = [
    'dispatcher',
    'remote_dispatcher',
    'marketing',
    'management',
    'administrator',
    'developer',
  ];

  /// Admin roles with elevated permissions
  static const List<String> adminRoles = [
    'administrator',
    'developer',
  ];

  /// Management roles
  static const List<String> managementRoles = [
    'administrator',
    'developer',
    'management',
  ];
}

/// Streaming constants
class StreamingConstants {
  StreamingConstants._();

  /// Default stream FPS
  static const int defaultStreamFps = 2;

  /// Default stream quality (JPEG quality 0-100)
  static const int defaultStreamQuality = 50;

  /// Screenshot JPEG quality
  static const int screenshotJpegQuality = 75;

  /// Minimum stream FPS
  static const int minStreamFps = 1;

  /// Maximum stream FPS
  static const int maxStreamFps = 30;
}
