# Changelog

All notable changes to A1 Tools will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Version Format

- **MAJOR.MINOR.PATCH** (e.g., 4.1.67)
- **MAJOR**: Breaking changes requiring user action or data migration
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, small improvements

---

## [Unreleased]

### Planned
- Integration tests for critical flows
- E2E testing

---

## [4.2.0] - 2026-01-20

### Added
- **A1-CRM**: Complete field service management system (Workiz replacement)
  - **Dashboard** with KPIs, revenue metrics, activity feed, and quick actions
  - **Client Management** with contact info, multiple properties, job history
  - **Job/Work Order Management** with status workflow, line items, scheduling
  - **Lead Pipeline** with kanban-style stages (New, Contacted, Qualified, Proposal, Negotiation, Won, Lost)
  - **Estimates** with line items, signatures, send/approve workflow
  - **Invoices** with payments, overdue tracking, multiple payment methods
  - **Schedule/Calendar** with technician timeline and availability
  - **Map View** for technician locations and job dispatch
  - **Call Logging** with Twilio webhook integration
  - **Price Book** (service catalog) with categories
  - **Reports & Analytics** (revenue, jobs, leads, technician performance)
  - **Workflow Automation** with SMS/Email templates and triggers
  - **Settings** for numbering format, tax rates, business info

- **A1-CRM Backend APIs** (14 PHP files in `api/main/`)
  - `a1crm_init.php` - Database table creation (20+ tables)
  - `a1crm_dashboard.php` - KPIs, charts, activity feed
  - `a1crm_clients.php` - Client CRUD, properties, notes
  - `a1crm_jobs.php` - Job management, status workflow, line items
  - `a1crm_leads.php` - Lead pipeline, conversion to client/job
  - `a1crm_estimates.php` - Estimate builder, signatures, conversion
  - `a1crm_invoices.php` - Billing, payments, overdue tracking
  - `a1crm_schedule.php` - Calendar events, technician availability
  - `a1crm_map.php` - Technician GPS locations
  - `a1crm_calls.php` - Call log, Twilio webhooks
  - `a1crm_price_book.php` - Service/product catalog
  - `a1crm_reports.php` - Analytics, CSV exports
  - `a1crm_automations.php` - Workflow rules, templates
  - `a1crm_settings.php` - CRM configuration

- **A1-CRM Flutter UI** (`lib/features/a1crm/`)
  - Main navigation hub with desktop NavigationRail and mobile BottomNavigationBar
  - Dashboard, Clients, Jobs, and Leads screens implemented
  - Data models: `CrmClient`, `CrmJob`, `CrmLead` with enums
  - Service singleton `A1CrmService` with API integration
  - Responsive layouts for desktop and mobile

- **Home Screen Integration**
  - New "A1-CRM" button visible to all logged-in users
  - Navigates to field service management system

- **Management Screen Integration**
  - New "A1-CRM Settings" entry (admin only)
  - Database initialization, numbering prefixes, tax settings

---

## [4.1.67] - 2026-01-19

### Added
- **Management Screen Refactor**
  - Converted from single scrollable page to category-based navigation
  - New hub screen with list of category buttons
  - Dedicated screens for each category:
    - Administration (Authenticator, HR, User Management)
    - Sunday CRM (Board Templates, Monday Import, Settings)
    - Training (Study Guide Editor, Test Editor, Dashboard)
    - Integrations (FCM, Google Maps, Mailchimp, SMTP, Twilio, WordPress, Workiz)
    - Metrics (Analytics, Compliance, Office Map, Payroll, Time Records)
    - Inventory (Inventory Settings + Coming Soon items)
    - App Settings (PDF Logo, Minimum Version, Push Update, Lock Screen, Privacy, Suggestions, Role Access)
  - Shared base components in `management_screens/management_base.dart`

- **Terms of Service Screen** (`lib/features/legal/terms_of_service_screen.dart`)
  - Comprehensive Terms of Service covering all app capabilities
  - Sections: Introduction, Authorized Use, User Accounts, Data Collection & Monitoring, Application Features, Acceptable Use Policy, Confidentiality, Intellectual Property, Disclaimer, Termination, Changes to Terms, Contact Information
  - Theme-aware styling with accent-colored section headers

- **Footer Settings & Terms Links**
  - Settings icon (gear) opens Dependencies screen (Windows only)
  - Terms icon (document) opens Terms of Service screen
  - Both icons with tooltips in the home screen footer

- **Centralized App Constants** (`lib/core/constants/app_constants.dart`)
  - `TimeConstants` - Heartbeat intervals, polling intervals, session timeouts
  - `NetworkConstants` - HTTP timeouts, retry configuration, status codes
  - `PaginationConstants` - Page sizes, search limits
  - `ValidationConstants` - Field lengths, patterns, file size limits
  - `UIConstants` - Animation durations, snackbar timing
  - `CacheConstants` - TTL presets for different cache types
  - `RoleConstants` - Clock-required roles, admin roles, management roles
  - `StreamingConstants` - FPS, quality settings for screen streaming

- **Enhanced Cache Configuration Presets** (`lib/core/services/cache_manager.dart`)
  - Endpoint-type presets: `alerts`, `realtime`, `userProfile`, `settings`, `staticLists`, `referenceData`, `searchResults`, `paginatedList`, `analytics`, `media`
  - Factory method `CacheConfig.withTtl()` for custom TTL
  - `copyWithTtl()` method for modifying existing configs

- **API Client Retry Logic** (`lib/core/services/api_client.dart`)
  - `RetryConfig` class with `none`, `standard`, `aggressive` presets
  - Exponential backoff with jitter
  - Configurable retry status codes (502, 503, 504, 429)
  - Optional `retryConfig` parameter on GET, POST, PUT, DELETE methods

- **WebSocket Command Channel** (`lib/features/monitoring/remote_monitoring_service.dart`)
  - WebSocket-based command reception for remote monitoring
  - Fallback to HTTP polling if WebSocket unavailable
  - Uses unified `WebSocketClient` with auto-reconnect

- **Result Pattern for TimeClockService**
  - New `getStatusResult()` method returning `Result<ClockStatus>`
  - Better error handling with typed failures

- **Inspection Validation** (`lib/features/inspection/inspection_service.dart`)
  - `_validateInspection()` method checking required fields
  - Time constraint validation (max 24 hours)
  - Photo limit validation (max 50 per inspection)

### Fixed
- **DateTime Parsing Safety** - Added `_tryParseDateTime()` helper in TimeClockService to safely parse dates without exceptions
- **AsyncState.toLoading() Type Safety** - Changed from unsafe cast to null check pattern
- **WebSocket Memory Leak** - Made `dispose()` async with proper awaiting and try-catch around sink.close()
- **AuthService Logout Race Condition** - Used `Future.wait()` for atomic credential deletion
- **Inspection List Cast Safety** - Safe mapping with `toString()` instead of unchecked cast
- **BaseRepository Cache Key Collisions** - Changed to per-ID cache map (`Map<ID, CacheManager<T>>`)
- **String Interpolation Error** - Fixed `remote_monitoring_viewer.dart` missing `$` in dimension string
- **WebSocket Config Parameters** - Fixed `enablePing` (removed) and `messages` → `messageStream` in remote monitoring

### Changed
- **Dependencies Button Relocated** - Moved from home screen menu to footer settings icon (Windows only)
- **RemoteMonitoringService Version** - Now uses `VersionCheckService.instance.currentVersion` instead of hardcoded version
- **Screenshot Conversion** - Uses `image` package with isolate `compute()` for pure-Dart BMP→JPEG conversion

### Technical
- New directory structure: `lib/features/admin/management_screens/`
- New directory structure: `lib/features/legal/`

---

## [4.1.x] - 2026-01-07 to 2026-01-18

### Added
- **CRM Home Screen Notifications**
  - Badge count on CRM button showing new assignments, updates, and overdue items
  - New `api/crm/notifications.php` API endpoint for notification counts
  - Polls every 30 seconds for CRM notification updates

- **Calendar Integration with CRM Due Dates**
  - CRM tasks with due dates now appear in the Calendar view
  - Items assigned to the user are shown as calendar events
  - Color-coded by priority (Urgent: red, High: orange, Normal: blue)

- **Board Template Automations**
  - Templates can now include board automations
  - "Include automations" checkbox in Save as Template dialog
  - Automations are restored when creating a board from a template

- **Subitems Display in Table View**
  - Subitems now display directly under their parent items in the table view
  - New `SubitemRow` widget with checkbox, due date, and assignee display
  - API now returns subitems when fetching board data

### Fixed
- **Dark Mode Improvements**
  - Date and Due Date cells now use theme-aware colors
  - Subitem rows properly styled for dark mode
  - Subitem section in item detail panel uses theme colors

- **Groups Count Display**
  - Workspace tabs now correctly show the number of groups in each board
  - Added `groupCount` field to CrmBoard model

### Changed
- Removed "Edit Labels" option from status/priority dropdown menus (use Board Settings instead)

---

## [4.0.x] - 2026-01-07

### Added
- **Testing Infrastructure** (`test/`)
  - `test/helpers/test_helpers.dart` - Widget test utilities
  - `test/helpers/mocks.dart` - Mock classes using mocktail
  - `TestDataFactory` - Factory methods for test data
  - Unit tests for `Result<T>`, `AsyncState<T>`, `AppError`
  - Added `mocktail: ^1.0.4` dev dependency

---

## [3.9.54] - 2026-01-07

### Added
- **Repository Pattern** (`lib/core/repository/`)
  - `Result<T>` - Type-safe success/failure wrapper
  - `ReadRepository<T, ID>` - Interface for read operations
  - `CrudRepository<T, ID>` - Interface for CRUD operations
  - `ApiRepository<T, ID>` - Base implementation for API-backed repos
  - `BaseRepository<T, ID>` - Full implementation with caching
  - `InMemoryRepository<T, ID>` - For testing and mocking
  - `CachedRepository` mixin - Add caching to any repository
  - `PagedResult<T>` - For paginated responses

---

## [3.9.53] - 2026-01-07

### Added
- **State Management Enhancement** (`lib/core/state/`)
  - `AsyncState<T>` - Generic state for loading/success/error with data
  - `AsyncStateNotifier<T>` - Base class for async operations
  - `PaginatedState<T>` and `PaginatedStateNotifier<T>` - For paginated lists
  - `FormState<T>` - Form data with validation
  - `AsyncStateBuilder` - Widget for building UI from state
  - `PaginatedListView` - List with built-in pagination
  - Pattern matching with `state.when()` and `state.maybeWhen()`

---

## [3.9.52] - 2026-01-07

### Added
- **WebSocket Client** (`lib/core/services/websocket_client.dart`)
  - Unified WebSocket client with auto-reconnection
  - Exponential backoff with jitter for reconnects
  - Connection state management (disconnected, connecting, connected, reconnecting)
  - Event streams for state, messages, typed events, and errors
  - Presets: `WebSocketConfig.standard`, `.monitoring`, `.notifications`
  - `WebSocketManager` for managing multiple connections
  - `WebSocketMixin` for easy widget integration

### Changed
- Registered `WebSocketManager` in service locator
- Updated README with WebSocket documentation

---

## [3.9.50] - 2026-01-07

### Added
- **Dependency Injection** (`lib/core/di/service_locator.dart`)
  - Added `get_it` package for DI
  - Services accessible via `getIt<ServiceType>()`
  - Foundation for improved testability

- **Unified Caching Layer** (`lib/core/services/cache_manager.dart`)
  - `CacheManager<T>` with configurable TTL
  - `CacheConfig` presets: short (1m), standard (5m), long (30m), persistent (1h)
  - `SimpleCache<K,V>` for key-value caching
  - `CacheRegistry` for managing multiple caches
  - Optional disk persistence
  - Stale-while-revalidate support

- **Centralized Error Handling** (`lib/core/services/error_handler.dart`)
  - `AppError` class with error types (network, server, auth, validation, etc.)
  - `ErrorHandler` with SnackBar/Dialog display methods
  - `BuildContext` extensions: `context.showError()`, `context.showSuccess()`
  - Retry button support for transient errors

- **Retry Helper** (`lib/core/utils/retry_helper.dart`)
  - Exponential backoff with jitter
  - `RetryConfig` presets: quick (2 attempts), standard (3), aggressive (5)
  - Async and callback-based retry patterns

- **Error Widgets** (`lib/core/widgets/error_widgets.dart`)
  - `ErrorBanner` - Dismissible error banner
  - `ErrorView` - Full-screen error with retry
  - `ErrorText` - Inline error text
  - `LoadingErrorOverlay` - Combined loading/error state

### Changed
- **Unified API Client** (`lib/core/services/api_client.dart`)
  - All HTTP methods now return `AppError` in responses
  - Added `onAppError` callback for global error handling
  - Improved error categorization by status code

- **InventoryService** migrated to use `CacheManager`

- **Code Organization** - Reorganized into feature folders:
  - `lib/features/` - Feature-specific screens and services
  - `lib/core/` - Shared infrastructure (DI, services, utils, widgets)

### Technical
- Backup created at `lib_backup_before_di/` before DI changes
- All existing functionality preserved

---

## [3.9.47] - 2026-01-07

### Added
- Centralized API configuration (`lib/config/api_config.dart`)
  - All 50+ API endpoints in one location
  - Helper methods for dynamic URLs (Google Maps, YouTube, etc.)
  - Easy environment switching capability

### Changed
- Migrated 73 files from hardcoded URLs to `ApiConfig` references
- Improved maintainability for API endpoint management

### Technical
- No functional changes to app behavior
- All existing features work identically

---

## [3.9.46] - 2026-01-06

### Notes
- Previous release before API config centralization
- This changelog begins tracking changes from this point forward

---

## Version History (Pre-Changelog)

Versions prior to 3.9.46 were not tracked in detail in this changelog.
Below is a reconstructed history of major milestones.

---

## [3.9.x] - Early 2026

### Added
- Workiz integration with WebView authentication
- WordPress site management and content integration
- Google Maps route optimization
- System metrics collection and dashboard

---

## [3.8.x] - Late 2025

### Added
- Remote monitoring with screenshot capture (Windows)
- System tray integration for background operation
- Real-time WebSocket alerts system
- Push notifications via Firebase Cloud Messaging
- Chat notification system with desktop alerts

---

## [3.7.x] - Mid 2025

### Added
- Marketing tools suite:
  - Mailchimp email campaign integration
  - Twilio SMS marketing
  - Blog editor with WordPress publishing
- Calendar integration with Syncfusion
- Route optimization with Google Maps

---

## [3.6.x] - Early 2025

### Added
- Inventory management system:
  - Complete stock tracking
  - Barcode/QR code scanning (mobile)
  - Stock in/out operations
  - Location-based inventory
  - Transfer between locations
  - Low stock alerts
- CSV export functionality

---

## [3.5.x] - Late 2024

### Added
- Time clock system:
  - Clock in/out with geolocation
  - 2-minute heartbeat monitoring
  - Work hour tracking and compliance
  - Manager approval workflow
  - Day-off scheduling
- HR employee management module

---

## [3.4.x] - Mid 2024

### Added
- Training system:
  - Test creation with question banks
  - Knowledge base with WYSIWYG editor
  - Real-time progress tracking
  - Role-based test assignments
  - Study mode vs test mode
  - Automatic grading

---

## [3.3.x] - Early 2024

### Added
- Field inspection system:
  - Inspection form creation
  - Photo capture with captions
  - Address and chimney type tracking
  - Issue documentation
  - PDF report generation
  - Signature capture

---

## [3.2.x] - Late 2023

### Added
- User authentication system:
  - Secure login/registration
  - Role-based access control (6 roles)
  - Session persistence with encrypted storage
  - Password reset functionality
- Virtual machine detection and blocking
- Developer bypass authentication

---

## [3.1.x] - Mid 2023

### Added
- Initial multi-platform Flutter application
- Windows desktop support with WebView2
- iOS and Android mobile support
- Basic navigation and theme system

---

## [3.0.0] - Early 2023

### Added
- Project inception
- Core Flutter framework setup
- Initial architecture design

---

## Legacy Milestones Summary

| Version Range | Timeframe | Major Features |
|--------------|-----------|----------------|
| 3.0.x | Early 2023 | Project inception |
| 3.1.x | Mid 2023 | Multi-platform foundation |
| 3.2.x | Late 2023 | Authentication, VM detection |
| 3.3.x | Early 2024 | Inspection system |
| 3.4.x | Mid 2024 | Training system |
| 3.5.x | Late 2024 | Time clock, HR |
| 3.6.x | Early 2025 | Inventory management |
| 3.7.x | Mid 2025 | Marketing tools |
| 3.8.x | Late 2025 | Remote monitoring, alerts |
| 3.9.x | Early 2026 | Integrations, CRM |

### Supported Platforms (All Versions)
- Windows (primary)
- iOS
- Android
- macOS
- Linux

---

## How to Update This File

When releasing a new version:

1. Move items from `[Unreleased]` to a new version section
2. Add the release date
3. Increment version in `pubspec.yaml`
4. Use these categories:
   - **Added**: New features
   - **Changed**: Changes to existing functionality
   - **Deprecated**: Features to be removed in future
   - **Removed**: Removed features
   - **Fixed**: Bug fixes
   - **Security**: Security-related changes
   - **Technical**: Internal changes (refactoring, dependencies)

### Example Entry

```markdown
## [3.10.0] - 2026-02-01

### Added
- New employee onboarding workflow
- Bulk inspection export to CSV

### Fixed
- Login timeout on slow connections
- Profile picture upload crash on iOS

### Changed
- Improved training test UI responsiveness
```
