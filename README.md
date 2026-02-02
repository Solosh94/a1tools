# A1 Tools

Enterprise business management application for A1 Chimney Specialist.

**Current Version:** 4.1.67

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Platforms](#platforms)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Feature Modules](#feature-modules)
- [Core Services](#core-services)
- [API Integrations](#api-integrations)
- [User Roles](#user-roles)
- [Configuration](#configuration)
- [Testing](#testing)
- [Dependencies](#dependencies)
- [Security](#security)
- [Version History](#version-history)

---

## Overview

A1 Tools is a comprehensive multi-platform Flutter application designed to streamline business operations for A1 Chimney Specialist. The application provides tools for:

- **Field Operations** - Inspections, reports, and job management
- **Employee Management** - Training, time tracking, and compliance
- **Inventory Control** - Stock management with barcode scanning
- **Communication** - Real-time alerts, chat, and notifications
- **Remote Monitoring** - Screen capture and system metrics
- **Marketing** - Email and SMS campaign management
- **Third-party Integrations** - Workiz, WordPress, Mailchimp, Twilio

---

## Features

### Authentication & Security
- Secure user login and registration
- Role-based access control (6 roles)
- Session persistence with encrypted storage
- Virtual machine detection and blocking
- Developer bypass authentication
- Two-factor verification for sensitive operations

### Field Inspections
- Create detailed field inspection reports
- Photo capture with captions
- Address and chimney type tracking
- Issue documentation with notes
- Offline draft saving capability
- PDF report generation
- Signature capture
- Integration with Workiz jobs

### Training System
- Create and manage training tests with question banks
- Knowledge base with rich content editor (WYSIWYG)
- Real-time progress tracking
- Role-based test assignments
- Study mode vs test mode
- Automatic grading with detailed results
- Training dashboard for managers
- Attempt management and reset capabilities

### Time Clock & Scheduling
- Clock in/out with geolocation
- 2-minute heartbeat monitoring
- Role-based clock-in requirements
- Work hour tracking and compliance
- Manager approval workflow
- Auto clock-out for inactive users
- Day-off scheduling
- Overtime tracking

### Inventory Management
- Complete stock tracking system
- Barcode/QR code scanning (mobile)
- Stock in/out operations
- Location-based inventory
- Transfer between locations
- Inventory adjustments
- Purchase order generation
- Low stock alerts
- Category management
- CSV export functionality

### Remote Monitoring (Windows)
- Periodic screenshot capture (configurable intervals)
- Real-time screen streaming
- System metrics collection (CPU, memory, disk, network)
- Remote mouse/keyboard control via FFI
- Capture protection for developers
- Activity heartbeat monitoring

### Alerts & Notifications
- Real-time WebSocket-based alert system
- Push notifications (Firebase Cloud Messaging)
- Chat notifications with desktop alerts
- Alert administration and filtering
- Sound notifications
- File attachments in alerts

### Marketing Tools
- **Email Campaigns** - Mailchimp integration
- **SMS Marketing** - Twilio integration
- **Blog Management** - WordPress content editor
- SMTP configuration

### Calendar & Scheduling
- Event scheduling and management
- Syncfusion calendar integration
- Appointment management
- Team scheduling view

### Route Optimization
- Google Maps integration
- GPS route optimization
- Distance matrix calculations
- Turn-by-turn directions

### Integration Features
- **Workiz** - Job sync, estimates, customer data, WebView login
- **WordPress** - Site management, content integration
- **Google Maps** - Maps, directions, geocoding

### Admin Features
- User management and deletion
- Role accessibility configuration
- Data analysis and metrics viewing
- Payroll management
- Logo configuration
- FCM/Push notification settings
- Minimum version enforcement
- VM detection settings
- Batch image editor/resizer
- Report lookup
- System metrics dashboard
- Lock screen exceptions management
- Privacy exclusions for monitoring
- Suggestion review and management

### Legal & Compliance
- Terms of Service screen with comprehensive coverage
- Data collection and monitoring disclosure
- Confidentiality and intellectual property policies

---

## Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| **Windows** | Primary | System tray, WebView2, FFI for screen capture, remote control |
| **iOS** | Supported | App Store distribution (ID: 6738715498) |
| **Android** | Supported | Google Play distribution |
| **macOS** | Supported | Desktop notifications |
| **Linux** | Basic | Limited feature support |

---

## Getting Started

### Prerequisites

- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2
- **Windows:** Visual Studio 2022 with C++ desktop workload
- **Windows:** WebView2 Runtime (usually pre-installed on Windows 10/11, required for embedded web content)
- **iOS/macOS:** Xcode 15+
- **Windows Installer:** Inno Setup 6

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd a1_tools

# Install dependencies
flutter pub get

# Run the app
flutter run

# Build for Windows
flutter build windows --release

# Build for iOS
flutter build ios --release

# Build for Android
flutter build apk --release
```

### Windows Installer

```bash
# Build release first
flutter build windows --release

# Create installer (requires Inno Setup 6)
cd installer
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=4.1.67 a1-tools.iss
```

---

## Project Structure

```
lib/
├── main.dart                 # App entry point with VM detection, version checks
├── app_theme.dart            # Centralized theme & color definitions
├── home_screen.dart          # Main dashboard screen
├── config/
│   └── api_config.dart       # Centralized API endpoints (60+ endpoints)
├── core/
│   ├── constants/
│   │   └── app_constants.dart     # Centralized magic numbers and config values
│   ├── di/
│   │   └── service_locator.dart   # Dependency injection (get_it)
│   ├── models/
│   │   └── app_error.dart         # Error types and classes
│   ├── providers/
│   │   └── theme_provider.dart    # Theme state management
│   ├── services/
│   │   ├── api_client.dart        # Unified HTTP client with retry logic
│   │   ├── cache_manager.dart     # Caching layer with TTL and presets
│   │   ├── error_handler.dart     # Centralized error handling
│   │   ├── websocket_client.dart  # WebSocket with auto-reconnect
│   │   ├── version_check_service.dart # App version checking
│   │   ├── app_update_checker.dart
│   │   ├── auto_updater.dart
│   │   └── update_manager.dart
│   ├── repository/
│   │   ├── repository.dart        # Repository interfaces and Result<T>
│   │   └── base_repository.dart   # Base implementations with per-ID caching
│   ├── state/
│   │   ├── async_state.dart       # Generic async state classes
│   │   ├── state_notifier.dart    # Base notifier classes
│   │   └── state_builder.dart     # UI builder widgets
│   ├── utils/
│   │   ├── retry_helper.dart      # Retry with exponential backoff
│   │   ├── csv_exporter.dart      # CSV export utility
│   │   └── keyboard_shortcuts.dart # Desktop keyboard shortcuts
│   └── widgets/
│       ├── error_widgets.dart     # Error UI components
│       ├── loading_skeleton.dart  # Shimmer loading animations
│       ├── confirmation_dialog.dart # Confirmation dialogs
│       └── searchable_list.dart   # Searchable list widget
├── features/
│   ├── admin/                # Admin screens (19 screens)
│   │   ├── batch_image_editor_screen.dart
│   │   ├── data_analysis_screen.dart
│   │   ├── fcm_config_screen.dart
│   │   ├── logo_config_screen.dart
│   │   ├── management_screen.dart
│   │   ├── minimum_version_screen.dart
│   │   ├── payroll_screen.dart
│   │   ├── role_accessibility_screen.dart
│   │   ├── user_delete_screen.dart
│   │   ├── user_management_screen.dart
│   │   ├── user_metrics_detail_screen.dart
│   │   ├── vm_settings_screen.dart
│   │   └── ...
│   ├── alerts/               # Alert system
│   │   ├── alerts_manager.dart
│   │   ├── alert_admin_screen.dart
│   │   └── chat_notification_service.dart
│   ├── auth/                 # Authentication
│   │   ├── auth_service.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── authenticator_screen.dart
│   ├── calendar/             # Calendar & scheduling
│   ├── compliance/           # Compliance monitoring
│   │   ├── compliance_service.dart
│   │   └── heartbeat_manager.dart
│   ├── inspection/           # Field inspections
│   │   ├── inspection_form_screen.dart
│   │   └── inspection_service.dart
│   ├── integration/          # Third-party integrations
│   │   ├── workiz_service.dart
│   │   └── wordpress_service.dart
│   ├── inventory/            # Inventory management
│   │   ├── inventory_dashboard_screen.dart
│   │   ├── inventory_scanner_screen.dart
│   │   └── inventory_service.dart
│   ├── marketing/            # Marketing tools
│   │   ├── email_campaign_screen.dart
│   │   ├── sms_marketing_screen.dart
│   │   └── blog_editor_screen.dart
│   ├── monitoring/           # Remote monitoring
│   │   ├── remote_monitoring_service.dart
│   │   ├── system_metrics_service.dart
│   │   └── capture_protection_service.dart
│   ├── profile/              # User profiles
│   ├── route/                # Route optimization
│   ├── security/             # Security features
│   │   └── vm_detection_service.dart
│   ├── suggestions/          # User feedback
│   ├── testing/              # Training (legacy name)
│   │   ├── training_service.dart
│   │   ├── training_dashboard_screen.dart
│   │   ├── test_screen.dart
│   │   └── knowledge_base_screen.dart
│   └── timeclock/            # Time tracking
│       ├── time_clock_service.dart
│       ├── time_clock_manager.dart
│       └── clock_lock_screen.dart
├── widgets/                  # Reusable UI components
│   ├── address_autocomplete.dart
│   ├── alert_popup_dialog.dart
│   ├── auth_dialog.dart
│   ├── captioned_image_picker.dart
│   ├── home_app_bar.dart
│   ├── home_button_styles.dart
│   ├── home_content_buttons.dart
│   ├── invoice_items_picker.dart
│   ├── preview_mode_banner.dart
│   ├── push_update_overlay.dart
│   ├── signature_capture.dart
│   ├── update_checker_footer.dart
│   └── workiz_job_selector.dart
├── metrics/                  # System metrics collection
├── hr/                       # HR module
└── l10n/                     # Localization
```

---

## Architecture

### Design Patterns

The application follows a modular, feature-based architecture with:

- **Feature-based structure** - Each feature in its own directory
- **Repository pattern** - Type-safe data access with `Result<T>`
- **Service locator** - Dependency injection via `get_it`
- **State management** - Custom `AsyncState<T>` pattern + Provider

### Unified API Client

All HTTP communication uses the centralized `ApiClient`:

```dart
import 'core/services/api_client.dart';

final api = ApiClient.instance;
final response = await api.get('$baseUrl/endpoint');

if (response.success) {
  final data = response.rawJson;
} else {
  print(response.message); // User-friendly error
  print(response.error);   // AppError with details
}
```

### Error Handling

Centralized error handling with user-friendly messages:

```dart
import 'core/services/error_handler.dart';
import 'core/models/app_error.dart';

// Show error snackbar
context.showError('Something went wrong');

// Handle AppError with retry option
if (response.error != null) {
  context.handleError(response.error!, onRetry: () => loadData());
}
```

### Caching

Unified caching with configurable TTL:

```dart
import 'core/services/cache_manager.dart';

final cache = CacheManager<List<Item>>(
  key: 'items',
  config: CacheConfig.standard, // 5 min TTL
);

final result = await cache.getOrFetch(() => api.fetchItems());
```

### State Management

Enhanced state management with `AsyncState` pattern:

```dart
import 'core/state/state.dart';

// Define a notifier
class UserNotifier extends AsyncStateNotifier<User> {
  Future<void> loadUser(int id) => loadData(() => api.getUser(id));
}

// Use in UI with AsyncStateBuilder
AsyncStateBuilder<User>(
  state: userNotifier.state,
  builder: (user) => Text(user.name),
  onRetry: () => userNotifier.loadUser(id),
)
```

Available patterns:
- **AsyncState<T>** - Loading/success/error states with data
- **AsyncStateNotifier<T>** - Base class for async operations
- **PaginatedState<T>** - For paginated lists with load more
- **AsyncStateBuilder** - Widget for building UI from state
- **Result<T>** - Type-safe success/failure wrapper

### CSV Export

Export data to CSV files:

```dart
import 'core/utils/csv_exporter.dart';

final result = await CsvExporter.export(
  data: items,
  config: CsvExportConfig(
    headers: ['Name', 'SKU', 'Quantity'],
    rowExtractor: (item) => [item.name, item.sku, '${item.qty}'],
    filename: 'inventory',
  ),
);
```

### Loading Skeletons

Show shimmer loading placeholders:

```dart
import 'core/widgets/loading_skeleton.dart';

SkeletonLoader(
  isLoading: _loading,
  skeleton: SkeletonListBuilder.listItems(itemCount: 5),
  child: MyListView(),
)
```

### Confirmation Dialogs

Show confirmation dialogs for destructive actions:

```dart
import 'core/widgets/confirmation_dialog.dart';

// Simple delete confirmation
final confirmed = await context.confirmDelete(
  itemName: 'Product XYZ',
  itemType: 'product',
);

// Type-to-confirm for dangerous operations
final confirmed = await context.confirmDangerous(
  title: 'Delete All Data',
  message: 'This will permanently delete all data.',
  typeToConfirm: 'DELETE',
);
```

### Keyboard Shortcuts

Add keyboard shortcuts for desktop:

```dart
import 'core/utils/keyboard_shortcuts.dart';

KeyboardShortcutScope(
  shortcuts: [
    ShortcutAction(
      id: 'save',
      label: 'Save',
      shortcut: AppShortcuts.save,
      action: () => _save(),
    ),
  ],
  child: MyScreen(),
)
```

---

## Feature Modules

### Authentication (`features/auth/`)
- User login/registration with secure credential storage
- Role-based access control
- Session persistence via FlutterSecureStorage
- Password reset functionality

### Inspections (`features/inspection/`)
- Field inspection form creation
- Photo capture with captions
- Address and chimney type tracking
- Issue documentation with notes
- Offline draft saving capability
- PDF report generation
- Workiz job integration

### Training (`features/testing/`)
- Test creation with question banks
- Knowledge base with rich content (flutter_quill)
- Real-time progress tracking
- Role-based test assignments
- Study mode and test mode
- Detailed results with answer review

### Time Clock (`features/timeclock/`)
- Clock in/out with scheduling
- 2-minute heartbeat monitoring
- Role-based clock-in requirements
- Work hour tracking
- Compliance monitoring
- Manager approval workflow

### Inventory (`features/inventory/`)
- Complete stock management
- Barcode/QR scanning
- Stock in/out operations
- Transfer between locations
- Inventory adjustments
- Low stock alerts
- Location management
- Category management

### Monitoring (`features/monitoring/`)
- Screenshot capture (configurable intervals)
- Real-time screen streaming
- System metrics collection
- Remote control capability
- Capture protection for developers

### Alerts (`features/alerts/`)
- Real-time WebSocket alerts
- Push notifications (FCM)
- Chat notifications
- Alert administration
- File attachments

### Marketing (`features/marketing/`)
- Email campaigns (Mailchimp)
- SMS marketing (Twilio)
- Blog post management

### Suggestions (`features/suggestions/`)
- User feedback and suggestion submission
- Status tracking (pending, reviewed, implemented, declined)
- Admin review interface with notes
- Suggestion history and management
- Anonymous or identified submissions

### Profile (`features/profile/`)
- User profile management
- Profile picture upload/removal (base64 encoded)
- Personal information editing (name, email, phone)
- Birthday tracking for team celebrations
- Password change functionality
- Role display (read-only)
- Session persistence with secure storage

---

## Core Services

| Service | Description |
|---------|-------------|
| `ApiClient` | Unified HTTP client with error handling, timeouts, logging |
| `CacheManager` | Memory caching with TTL, disk persistence |
| `ErrorHandler` | Centralized error handling with UI display |
| `WebSocketClient` | Real-time communication with auto-reconnection |
| `AuthService` | Login, registration, session management |
| `TimeClockService` | Clock in/out, attendance tracking |
| `ComplianceService` | Heartbeat monitoring, inactivity tracking |
| `RemoteMonitoringService` | Screenshot capture, screen streaming |
| `SystemMetricsService` | CPU, memory, disk, network metrics |
| `VmDetectionService` | Virtual machine detection |
| `AppUpdateChecker` | Version checking and update prompts |

---

## API Integrations

### Internal API
- **Base URL:** `https://tools.a-1chimney.com/api`
- **WordPress:** `https://tools.a-1chimney.com/wp-json/a1-tools/v1`
- **N8N Webhooks:** `https://a1tools.app.n8n.cloud/webhook`

### External Services

| Service | Purpose | Features |
|---------|---------|----------|
| **Workiz** | Job management | Job sync, estimates, customer data, WebView login |
| **WordPress** | Site management | Content integration, REST API |
| **Mailchimp** | Email marketing | Campaign creation and management |
| **Twilio** | SMS marketing | SMS sending and tracking |
| **Google Maps** | Route optimization | Maps, directions, distance matrix |
| **Firebase** | Push notifications | FCM for mobile notifications |

---

## User Roles

| Role | Access Level | Features |
|------|-------------|----------|
| `developer` | Full access + dev tools | All features, role preview, dev bypass |
| `admin` | Full access | All features except dev tools |
| `manager` | Team management | Reports, approvals, team oversight |
| `dispatcher` | Scheduling | Job assignments, scheduling, alerts |
| `marketing` | Marketing tools | Email, SMS, blog management |
| `technician` | Field work | Inspections, time clock, inventory |

---

## Configuration

### Environment Variables

The app connects to `https://tools.a-1chimney.com` for all API calls.

#### Flutter App Configuration

To change the server, update `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'https://your-server.com';
```

#### API Server Configuration

The API server uses environment variables loaded from a `.env` file. Create `api/.env` with:

```env
# Database Configuration
DB_HOST=localhost
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASS=your_database_password

# API Authentication
API_TOKEN=your_secure_api_token

# Environment (development, staging, production)
APP_ENV=production

# Timezone (used for all date/time operations)
APP_TIMEZONE=America/New_York
```

**Note:** Environment variables take precedence over `.env` file values. In production, set these directly in your server environment.

### Build Variants

```bash
# Debug
flutter run

# Release
flutter build windows --release
flutter build ios --release
flutter build apk --release
```

### API Configuration

All endpoints are centralized in `lib/config/api_config.dart`:

```dart
import 'config/api_config.dart';

// Use in services
final response = await api.get(ApiConfig.inspections);
```

---

## Testing

Run tests with:
```bash
flutter test
```

### Test Structure
```
test/
├── helpers/
│   ├── test_helpers.dart   # Widget test utilities
│   └── mocks.dart          # Mock classes (mocktail)
└── core/
    ├── result_test.dart    # Result<T> tests
    ├── async_state_test.dart # AsyncState tests
    └── app_error_test.dart # AppError tests
```

### Writing Tests
```dart
import 'package:flutter_test/flutter_test.dart';
import '../helpers/mocks.dart';
import '../helpers/test_helpers.dart';

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
  });

  test('fetches data successfully', () async {
    final userData = TestDataFactory.createUser(id: 1, name: 'Test');
    expect(result.isSuccess, isTrue);
  });
}
```

---

## Dependencies

### Key Packages

| Category | Package | Version | Purpose |
|----------|---------|---------|---------|
| State | `provider` | 6.1.5+1 | State management |
| DI | `get_it` | 7.6.7 | Dependency injection |
| HTTP | `http` | 1.2.2 | API communication |
| WebSocket | `web_socket_channel` | 2.4.0 | Real-time messaging |
| WebViews | `webview_flutter` | 4.9.0 | Embedded browser |
| | `webview_windows` | 0.4.0 | Windows WebView2 |
| Maps | `google_maps_flutter` | 2.5.3 | Maps integration |
| Scanning | `mobile_scanner` | 3.5.6 | Barcode/QR scanning |
| Documents | `pdf` | 3.11.0 | PDF generation |
| | `printing` | 5.13.1 | Document printing |
| Rich text | `flutter_quill` | 11.5.0 | WYSIWYG editor |
| Calendar | `syncfusion_flutter_calendar` | 29.2.11 | Calendar widget |
| Desktop | `window_manager` | 0.4.0 | Window control |
| | `system_tray` | 2.0.3 | System tray |
| Storage | `flutter_secure_storage` | 9.2.2 | Secure storage |
| | `shared_preferences` | 2.5.3 | Simple storage |
| Images | `image` | 4.2.0 | Image processing |
| Crypto | `crypto` | 3.0.3 | Cryptography |
| FFI | `ffi` | 2.1.3 | Native code |
| Animations | `lottie` | 3.1.2 | Lottie animations |

See `pubspec.yaml` for complete list.

---

## Security

### Implemented Security Features

- **Virtual Machine Detection** - Prevents unauthorized VM usage
- **Secure Storage** - FlutterSecureStorage for credentials
- **HTTPS Only** - All API communication uses HTTPS
- **Capture Protection** - Prevents screenshots on developer devices
- **Role-based Access** - Prevents unauthorized feature access
- **Version Enforcement** - Blocks outdated app versions
- **Token-based Auth** - Session management with tokens
- **TOTP Verification** - For sensitive operations

### Security Best Practices

- Credentials stored in encrypted storage
- Sensitive data sanitized from logs
- Certificate validation for API calls
- Session timeout handling
- Input validation on forms

---

## Version History

See [CHANGELOG.md](CHANGELOG.md) for release notes.

**Current Version:** 4.1.67

---

## Support

Internal use only. Contact the development team for support.

---

## License

Proprietary - A-1 Chimney Specialist

Copyright © 2024-2026 A-1 Chimney Specialist. All rights reserved.
