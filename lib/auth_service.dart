import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'database_helper.dart';

/// Handles app password setup, verification, and change.
///
/// The password itself is never stored. Instead we store a random salt
/// and the SHA-256 hash of (salt + password) in the existing app_settings
/// key/value table. On verify, we redo the hash with the stored salt and
/// compare.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _saltKey = 'auth_salt';
  static const _hashKey = 'auth_hash';
  static const _failedAttemptsKey = 'auth_failed_attempts';
  static const _lockUntilKey = 'auth_lock_until';

  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 1);

  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Whether a password has been set up yet. False on first run.
  Future<bool> hasPassword() async {
    final hash = await DatabaseHelper.instance.getAppSetting(_hashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets the password for the first time, or overwrites it directly
  /// (used by setup screen and by changePassword after verifying the old one).
  Future<void> setPassword(String password) async {
    final salt = _generateSalt();
    final hash = _hash(password, salt);
    await DatabaseHelper.instance.setAppSetting(_saltKey, salt);
    await DatabaseHelper.instance.setAppSetting(_hashKey, hash);
    await _clearLockoutState();
  }

  /// Verifies a password attempt. Tracks failed attempts and applies a
  /// short lockout after too many wrong tries, to slow down brute forcing.
  /// Returns true on success.
  Future<bool> verifyPassword(String password) async {
    final lockedUntil = await _lockedUntil();
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      return false;
    }

    final salt = await DatabaseHelper.instance.getAppSetting(_saltKey);
    final storedHash = await DatabaseHelper.instance.getAppSetting(_hashKey);
    if (salt == null || storedHash == null) return false;

    final attemptHash = _hash(password, salt);
    final ok = attemptHash == storedHash;

    if (ok) {
      await _clearLockoutState();
    } else {
      await _registerFailedAttempt();
    }
    return ok;
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final ok = await verifyPassword(oldPassword);
    if (!ok) return false;
    await setPassword(newPassword);
    return true;
  }

  /// Removes password protection entirely (requires current password).
  Future<bool> removePassword(String currentPassword) async {
    final ok = await verifyPassword(currentPassword);
    if (!ok) return false;
    await DatabaseHelper.instance.setAppSetting(_saltKey, '');
    await DatabaseHelper.instance.setAppSetting(_hashKey, '');
    await _clearLockoutState();
    return true;
  }

  Future<DateTime?> _lockedUntil() async {
    final text = await DatabaseHelper.instance.getAppSetting(_lockUntilKey);
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  /// Seconds remaining on an active lockout, or 0 if not locked.
  Future<int> lockoutSecondsRemaining() async {
    final until = await _lockedUntil();
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _registerFailedAttempt() async {
    final current = await DatabaseHelper.instance.getAppSetting(_failedAttemptsKey);
    final count = (int.tryParse(current ?? '0') ?? 0) + 1;
    await DatabaseHelper.instance.setAppSetting(_failedAttemptsKey, count.toString());

    if (count >= maxAttempts) {
      final until = DateTime.now().add(lockoutDuration);
      await DatabaseHelper.instance.setAppSetting(_lockUntilKey, until.toIso8601String());
      await DatabaseHelper.instance.setAppSetting(_failedAttemptsKey, '0');
    }
  }

  Future<void> _clearLockoutState() async {
    await DatabaseHelper.instance.setAppSetting(_failedAttemptsKey, '0');
    await DatabaseHelper.instance.setAppSetting(_lockUntilKey, '');
  }
}
