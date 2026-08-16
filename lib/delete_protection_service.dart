import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'database_helper.dart';

class DeleteProtectionService {
  DeleteProtectionService._();
  static final instance = DeleteProtectionService._();

  static const _saltKey = 'delete_password_salt';
  static const _hashKey = 'delete_password_hash';

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  String _salt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(24, (_) => r.nextInt(256)));
  }

  Future<bool> hasPassword() async {
    final hash = await DatabaseHelper.instance.getAppSetting(_hashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPassword(String password) async {
    final salt = _salt();
    await DatabaseHelper.instance.setAppSetting(_saltKey, salt);
    await DatabaseHelper.instance.setAppSetting(_hashKey, _hash(password, salt));
  }

  Future<bool> verifyPassword(String password) async {
    final salt = await DatabaseHelper.instance.getAppSetting(_saltKey);
    final hash = await DatabaseHelper.instance.getAppSetting(_hashKey);
    if (salt == null || hash == null || salt.isEmpty || hash.isEmpty) return false;
    return _hash(password, salt) == hash;
  }

  Future<bool> changePassword(String current, String next) async {
    if (!await verifyPassword(current)) return false;
    await setPassword(next);
    return true;
  }
}
