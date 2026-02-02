// Example Repository Implementation
//
// This file demonstrates how to migrate an existing service to use
// the repository pattern with dependency injection.
//
// BEFORE (old service pattern):
// ```dart
// class UserService {
//   static final UserService _instance = UserService._();
//   static UserService get instance => _instance;
//   UserService._();
//
//   Future<List<User>> getUsers() async {
//     final response = await ApiClient.instance.get(ApiConfig.users);
//     if (response.success) {
//       return (response.rawJson!['users'] as List)
//           .map((e) => User.fromJson(e)).toList();
//     }
//     return [];
//   }
// }
// ```
//
// AFTER (repository pattern):
// ```dart
// class UserRepository extends BaseRepository<User, int> {
//   UserRepository({required ApiClient api})
//       : super(api: api, endpoint: ApiConfig.users);
//
//   @override
//   User fromJson(Map<String, dynamic> json) => User.fromJson(json);
//   @override
//   Map<String, dynamic> toJson(User item) => item.toJson();
//   @override
//   int getId(User item) => item.id;
// }
// ```
//
// USAGE:
// ```dart
// // Register in service_locator.dart
// sl.registerLazySingleton<UserRepository>(
//   () => UserRepository(api: sl<ApiClient>()),
// );
//
// // Use in widgets
// final repo = getIt<UserRepository>();
// final result = await repo.getAll();
// result.when(
//   success: (users) => setState(() => _users = users),
//   failure: (error) => context.showError(error.message),
// );
// ```

import '../models/app_error.dart';
import '../services/cache_manager.dart';
import 'base_repository.dart';

/// Example: User model
class ExampleUser {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role;
  final DateTime? createdAt;

  const ExampleUser({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.role,
    this.createdAt,
  });

  factory ExampleUser.fromJson(Map<String, dynamic> json) {
    return ExampleUser(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
    };
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return firstName ?? lastName ?? username;
  }
}

/// Example: User Repository
///
/// Demonstrates the full repository pattern with:
/// - CRUD operations
/// - Caching
/// - Custom methods
/// - Dependency injection
class ExampleUserRepository extends BaseRepository<ExampleUser, int> {
  ExampleUserRepository({
    required super.api,
  }) : super(
          endpoint: 'user_management.php',
          // Cache individual users for 10 minutes
          itemCacheConfig: const CacheConfig(
            ttl: Duration(minutes: 10),
          ),
          // Cache user list for 5 minutes
          listCacheConfig: const CacheConfig(
            ttl: Duration(minutes: 5),
            staleWhileRevalidate: true,
          ),
        );

  @override
  ExampleUser fromJson(Map<String, dynamic> json) => ExampleUser.fromJson(json);

  @override
  Map<String, dynamic> toJson(ExampleUser item) => item.toJson();

  @override
  int getId(ExampleUser item) => item.id;

  @override
  String get listKey => 'users'; // API returns { "users": [...] }

  // ============================================================================
  // CUSTOM METHODS
  // ============================================================================

  /// Get user by username
  Future<Result<ExampleUser>> getByUsername(String username) async {
    final response = await api.get('$endpoint?action=get&username=$username');

    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('user')) {
        return Result.success(fromJson(data['user'] as Map<String, dynamic>));
      }
    }

    return Result.failure(
      response.error ?? AppError.notFound(details: 'User not found'),
    );
  }

  /// Get users by role
  Future<Result<List<ExampleUser>>> getByRole(String role) async {
    final response = await api.get('$endpoint?action=list&role=$role');

    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final users = data['users'] as List?;
      if (users != null) {
        return Result.success(
          users.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: 'Failed to fetch users'),
    );
  }

  /// Update user role
  Future<Result<bool>> updateRole(int userId, String newRole) async {
    final response = await api.post(
      endpoint,
      body: {
        'action': 'update_role',
        'user_id': userId,
        'role': newRole,
      },
    );

    if (response.success) {
      // Invalidate cache for this user
      invalidateItem(userId);
      return Result.success(true);
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: 'Failed to update role'),
    );
  }

  /// Search users
  @override
  Future<Result<List<ExampleUser>>> search(String query, {int limit = 20}) async {
    final response = await api.get(
      '$endpoint?action=search&q=${Uri.encodeComponent(query)}&limit=$limit',
    );

    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final users = data['users'] as List?;
      if (users != null) {
        return Result.success(
          users.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        );
      }
    }

    return Result.failure(
      response.error ?? AppError.unknown(message: 'Search failed'),
    );
  }
}

// =============================================================================
// MIGRATION GUIDE
// =============================================================================
//
// To migrate an existing service to use the repository pattern:
//
// 1. CREATE THE REPOSITORY:
//    - Extend BaseRepository<ModelType, IdType>
//    - Implement fromJson(), toJson(), getId()
//    - Override listKey if API uses different key than 'data'
//
// 2. REGISTER IN SERVICE LOCATOR:
//    ```dart
//    // In lib/core/di/service_locator.dart
//    sl.registerLazySingleton<UserRepository>(
//      () => UserRepository(api: sl<ApiClient>()),
//    );
//    ```
//
// 3. UPDATE USAGE IN WIDGETS:
//    ```dart
//    // Before:
//    final users = await UserService.instance.getUsers();
//
//    // After:
//    final repo = getIt<UserRepository>();
//    final result = await repo.getAll();
//    result.when(
//      success: (users) => setState(() => _users = users),
//      failure: (error) => showError(error.message),
//    );
//    ```
//
// 4. BENEFITS:
//    - Automatic caching
//    - Consistent error handling via Result<T>
//    - Easy to test (inject mock ApiClient)
//    - Clear data flow
//    - Type-safe
//
// 5. TESTING:
//    ```dart
//    test('getAll returns users', () async {
//      final mockApi = MockApiClient();
//      final repo = UserRepository(api: mockApi);
//
//      when(() => mockApi.get(any())).thenAnswer((_) async =>
//        ApiResponse(success: true, data: {'users': [...]})
//      );
//
//      final result = await repo.getAll();
//      expect(result.isSuccess, true);
//      expect(result.data, isNotEmpty);
//    });
//    ```
