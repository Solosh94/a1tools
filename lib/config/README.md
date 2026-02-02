# Config Module

This folder contains centralized configuration for the A1 Tools application.

## Files

### `api_config.dart`

Contains all API endpoints used throughout the application. This is the **single source of truth** for all server URLs.

## Usage

```dart
import 'config/api_config.dart';

// Use endpoints directly
final response = await http.get(Uri.parse(ApiConfig.inspections));

// Or use helper methods for dynamic URLs
final mapsUrl = ApiConfig.googleMapsDirectionsUrl(
  origin: '123 Main St',
  destination: '456 Oak Ave',
);
```

## Structure

The `ApiConfig` class is organized by category:

| Category | Examples |
|----------|----------|
| Base URLs | `baseUrl`, `apiBase`, `wpApiBase` |
| Authentication | `auth`, `passwordReset`, `userManagement` |
| Alerts & Chat | `alerts`, `chatMessages`, `chatGroups` |
| Inspections | `inspections`, `inspectionReports` |
| Training | `training`, `kbProgress` |
| Time Clock | `timeClock`, `officeMap`, `compliance` |
| Inventory | `inventory`, `inventoryLocations` |
| HR | `hr` |
| Metrics | `metrics`, `systemMetrics`, `screenshotGet` |
| Marketing | `mailchimpIntegration`, `twilioIntegration` |
| External | `googleMapsDirections`, `ipLookup` |

## Helper Methods

For URLs that require parameters, use the helper methods:

```dart
// Download URL for specific version
ApiConfig.installerDownload('3.9.47')
// Returns: https://tools.a-1chimney.com/downloads/A1-Tools-Setup-3.9.47.exe

// Google Maps directions
ApiConfig.googleMapsDirectionsUrl(origin: 'A', destination: 'B', waypoints: 'C|D')
// Returns: https://www.google.com/maps/dir/?api=1&origin=A&destination=B&waypoints=C|D&travelmode=driving

// YouTube embed
ApiConfig.youtubeEmbed('dQw4w9WgXcQ')
// Returns: https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&rel=0&modestbranding=1
```

## Modifying Endpoints

To change an endpoint:

1. Edit `api_config.dart`
2. Run `flutter analyze` to check for errors
3. Test affected features

To add a new endpoint:

1. Add constant to appropriate section in `api_config.dart`
2. Use the new constant in your service/screen
3. Document in this README if it's a new category

## Environment Switching

To switch between environments (e.g., dev/staging/prod):

```dart
// Option 1: Change baseUrl directly
static const String baseUrl = 'https://dev.a-1chimney.com';

// Option 2: Use environment variable (future improvement)
static String get baseUrl =>
  const String.fromEnvironment('API_BASE', defaultValue: 'https://tools.a-1chimney.com');
```

## Related Files

- `../auth_service.dart` - Uses auth endpoints
- `../inspection_service.dart` - Uses inspection endpoints
- `../training_service.dart` - Uses training endpoints
- All `*_service.dart` files reference `ApiConfig`
