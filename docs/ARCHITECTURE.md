# A1 Tools Architecture

## Overview

A1 Tools follows a service-oriented architecture with clear separation between UI, business logic, and data layers.

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │   Screens   │ │   Widgets   │ │  Providers  │            │
│  │  (*_screen) │ │  (widgets/) │ │ (*_provider)│            │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘            │
└─────────┼───────────────┼───────────────┼───────────────────┘
          │               │               │
          ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Service Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐            │
│  │ AuthService │ │ Inspection  │ │  Training   │  ...       │
│  │             │ │   Service   │ │   Service   │            │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘            │
└─────────┼───────────────┼───────────────┼───────────────────┘
          │               │               │
          ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                   Configuration Layer                        │
│                    ┌─────────────┐                          │
│                    │  ApiConfig  │                          │
│                    │ (endpoints) │                          │
│                    └──────┬──────┘                          │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Backend API                             │
│              https://tools.a-1chimney.com/api               │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                    # App entry point, routing, initialization
│
├── config/                      # Configuration
│   └── api_config.dart          # All API endpoints
│
├── widgets/                     # Reusable UI components
│   ├── home_app_bar.dart        # App bar with user info
│   ├── home_content_buttons.dart
│   ├── auth_dialog.dart
│   ├── update_checker_footer.dart
│   └── metrics_service.dart
│
├── metrics/                     # System metrics module
│   ├── screen_capture_manager.dart
│   ├── system_metrics_manager.dart
│   ├── metrics_service.dart
│   └── metrics_rest_client.dart
│
├── hr/                          # HR module
│   └── hr_service.dart
│
├── l10n/                        # Localization
│   └── app_localizations.dart
│
├── *_service.dart              # Service classes (business logic)
├── *_screen.dart               # Screen widgets (UI)
├── *_models.dart               # Data models
└── *_provider.dart             # State providers
```

## Design Patterns

### 1. Singleton Services

All services use the singleton pattern for global access:

```dart
class InspectionService {
  // Private constructor
  InspectionService._();

  // Single instance
  static final InspectionService _instance = InspectionService._();

  // Public accessor
  static InspectionService get instance => _instance;

  // Service methods
  Future<List<Inspection>> getInspections() async { ... }
}

// Usage
final inspections = await InspectionService.instance.getInspections();
```

### 2. Provider Pattern (State Management)

App-wide state uses the Provider package:

```dart
// Provider definition
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

// In main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => LanguageProvider()),
  ],
  child: MyApp(),
)

// Usage in widgets
final theme = context.watch<ThemeProvider>();
```

### 3. Centralized Configuration

All API endpoints are in one file:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://tools.a-1chimney.com';
  static const String apiBase = '$baseUrl/api';

  static const String auth = '$baseUrl/a1tools_auth.php';
  static const String inspections = '$apiBase/inspections.php';
  // ... 50+ more endpoints
}
```

## Module Breakdown

### Core Modules

| Module | Files | Description |
|--------|-------|-------------|
| Auth | `auth_service.dart`, `authenticator_screen.dart` | Login, registration, session management |
| Inspection | `inspection_*.dart` (6 files) | Field inspections, photos, PDF reports |
| Training | `training_*.dart` (8 files) | Tests, knowledge base, progress tracking |
| Time Clock | `time_clock_*.dart`, `time_records_screen.dart` | Clock in/out, scheduling |
| Inventory | `inventory_*.dart` | Stock management, barcode scanning |
| HR | `hr/hr_service.dart`, `hr_screen.dart` | Employee management |

### Supporting Modules

| Module | Files | Description |
|--------|-------|-------------|
| Alerts | `alerts_manager.dart`, `alert_admin_screen.dart` | Push notifications, chat |
| Metrics | `metrics/` folder | System monitoring, screenshots |
| Heartbeat | `heartbeat_*.dart` | Online status, compliance |
| Updates | `app_update_checker.dart`, `auto_updater.dart` | Version checking, silent updates |

### Integration Modules

| Module | Files | Description |
|--------|-------|-------------|
| Workiz | `workiz_*.dart` | Job sync, estimates |
| WordPress | `wordpress_sites_screen.dart`, `admin_wp_api_screen.dart` | Site management |
| Marketing | `mailchimp_*.dart`, `twilio_*.dart`, `sms_*.dart`, `email_*.dart` | Campaigns |
| Maps | `route_optimization_*.dart` | Google Maps routing |

## Data Flow

### API Request Flow

```
Screen (UI)
    │
    ▼
Service.method()
    │
    ▼
ApiConfig.endpoint
    │
    ▼
http.get/post(Uri.parse(endpoint))
    │
    ▼
JSON Response
    │
    ▼
Model.fromJson()
    │
    ▼
Return to Screen
```

### Example: Loading Inspections

```dart
// 1. Screen calls service
class InspectionListScreen extends StatefulWidget {
  @override
  _State createState() => _State();
}

class _State extends State<InspectionListScreen> {
  List<Inspection> _inspections = [];

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    // 2. Service makes API call
    final inspections = await InspectionService.instance.getInspections(
      username: widget.username,
    );

    // 3. Update UI
    setState(() => _inspections = inspections);
  }
}

// In InspectionService:
Future<List<Inspection>> getInspections({required String username}) async {
  // 4. Uses centralized endpoint
  final url = '$_baseUrl?action=list&username=$username';
  final response = await http.get(Uri.parse(url));

  // 5. Parse response
  final data = jsonDecode(response.body);
  return (data['inspections'] as List)
      .map((i) => Inspection.fromJson(i))
      .toList();
}
```

## Background Services

Several services run continuously in the background:

| Service | Interval | Purpose |
|---------|----------|---------|
| HeartbeatManager | 20 seconds | Report online status |
| AlertsManager | 10 seconds | Poll for new alerts |
| ChatNotificationService | 10 seconds | Check for messages |
| ComplianceService | 2 minutes | Compliance heartbeat |
| SystemMetricsService | 5 minutes | Collect system metrics |
| ScreenCaptureManager | 15 minutes | Capture screenshots |

## Platform-Specific Code

### Windows
- `webview_windows` for WebView2 integration
- FFI calls for screen capture (`remote_monitoring_service.dart`)
- System tray integration (`system_tray` package)
- Window management (`window_manager` package)

### iOS/Android
- `flutter_local_notifications` for push notifications
- `mobile_scanner` for barcode scanning
- `geolocator` for GPS

## Security Considerations

1. **Credential Storage**: Uses `flutter_secure_storage` for sensitive data
2. **Screen Capture Protection**: `no_screenshot` package prevents screenshots
3. **Role-Based Access**: UI elements hidden based on user role
4. **HTTPS Only**: All API calls use HTTPS

## Future Improvements

See [CHANGELOG.md](../CHANGELOG.md) for planned improvements:
- Unified API client with interceptors
- Repository pattern for data layer
- Dependency injection with `get_it`
- State management migration to Riverpod/BLoC
- Comprehensive test suite
