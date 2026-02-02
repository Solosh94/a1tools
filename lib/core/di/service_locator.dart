// Service Locator
//
// Centralized dependency injection setup using get_it.
// All services are registered here and can be accessed throughout the app.
//
// Benefits of using the service locator:
// 1. Easy to mock services for testing
// 2. Clear dependency graph
// 3. Lazy initialization improves startup time
// 4. Single source of truth for service instances

import 'package:get_it/get_it.dart';

import '../services/api_client.dart';
import '../services/cache_manager.dart';
import '../services/error_handler.dart';
import '../services/websocket_client.dart';

/// Global service locator instance
final GetIt sl = GetIt.instance;

/// Shorthand for accessing the service locator
/// Usage: `getIt<ApiClient>()`
T getIt<T extends Object>() => sl<T>();

/// Try to get a service, returns null if not registered
T? tryGetIt<T extends Object>() => sl.isRegistered<T>() ? sl<T>() : null;

/// Initialize all dependencies
/// Call this in main() before runApp()
Future<void> setupServiceLocator() async {
  // Core services (singletons)
  _registerCoreServices();

  // Repositories (data access layer)
  _registerRepositories();

  // Feature services (lazy singletons - created on first use)
  _registerFeatureServices();

  // Wait for async registrations to complete
  await sl.allReady();
}

/// Register core services that are always needed
void _registerCoreServices() {
  // API Client - singleton, used by all services and repositories
  sl.registerLazySingleton<ApiClient>(() => ApiClient.instance);

  // Error Handler - singleton for global error handling
  sl.registerLazySingleton<ErrorHandler>(() => ErrorHandler.instance);

  // Cache Registry - singleton for managing all caches
  sl.registerLazySingleton<CacheRegistry>(() => CacheRegistry.instance);

  // WebSocket Manager - singleton for managing WebSocket connections
  sl.registerLazySingleton<WebSocketManager>(() => WebSocketManager.instance);
}

/// Register repositories
/// Repositories handle data access and caching
void _registerRepositories() {
  // Repositories are registered here with their dependencies injected.
  // This enables easy testing by swapping out dependencies.
  //
  // Example:
  // sl.registerLazySingleton<UserRepository>(
  //   () => UserRepository(api: sl<ApiClient>()),
  // );
  //
  // sl.registerLazySingleton<InspectionRepository>(
  //   () => InspectionRepository(api: sl<ApiClient>()),
  // );
  //
  // sl.registerLazySingleton<SundayRepository>(
  //   () => SundayRepository(api: sl<ApiClient>()),
  // );
}

/// Register feature-specific services
/// These are created lazily when first accessed
void _registerFeatureServices() {
  // Services are registered lazily - they are only instantiated when first accessed.
  // This improves startup time and memory usage.
  //
  // Services should extend BaseService for standardized error handling and caching.
  // See lib/core/services/base_service.dart for the base class implementation.
  //
  // Example registration with dependency injection:
  //
  // sl.registerLazySingleton<AlertsService>(
  //   () => AlertsService(api: sl<ApiClient>()),
  // );
  //
  // sl.registerLazySingleton<TrainingService>(
  //   () => TrainingService(
  //     api: sl<ApiClient>(),
  //     cacheRegistry: sl<CacheRegistry>(),
  //   ),
  // );
}

/// Reset the service locator (useful for testing)
Future<void> resetServiceLocator() async {
  await sl.reset();
}

/// Check if a service is registered
bool isRegistered<T extends Object>() => sl.isRegistered<T>();

/// Unregister a service
void unregister<T extends Object>() {
  if (sl.isRegistered<T>()) {
    sl.unregister<T>();
  }
}
