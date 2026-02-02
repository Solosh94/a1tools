import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const _kAdminHeader = 'admin_basic_header';
  static const _kAdminSetAt  = 'admin_basic_set_at'; // epoch millis

  /// Save Basic header with current time (ms)
  static Future<void> saveAdminHeader(String header) async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _kAdminHeader, value: header);
    await _storage.write(key: _kAdminSetAt, value: now);
  }

  /// Load header only if age < [maxAgeDays]
  static Future<String?> loadAdminHeader({int maxAgeDays = 7}) async {
    final header = await _storage.read(key: _kAdminHeader);
    final setAtStr = await _storage.read(key: _kAdminSetAt);
    if (header == null || setAtStr == null) return null;

    final setAt = int.tryParse(setAtStr) ?? 0;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(setAt))
        .inDays;
    if (age >= maxAgeDays) return null;
    return header;
  }

  static Future<void> clearAdminHeader() async {
    await _storage.delete(key: _kAdminHeader);
    await _storage.delete(key: _kAdminSetAt);
  }
}
