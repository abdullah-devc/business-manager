import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_helper.dart';
import 'export_file_service.dart';

class BackupService {
  static const _format = 'business_manager_backup';
  static const _version = 2;

  static Future<Uint8List> createBackupBytes() async {
    final tables = await DatabaseHelper.instance.exportBackupData();
    final profile = tables['business_profile']?.isNotEmpty == true
        ? tables['business_profile']!.first
        : null;
    String? logoBase64;
    String? logoExtension;
    final logoPath = profile?['logo_path']?.toString() ?? '';
    if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
      logoBase64 = base64Encode(await File(logoPath).readAsBytes());
      logoExtension = extension(logoPath).isEmpty ? '.png' : extension(logoPath);
    }
    final attachments = <Map<String, dynamic>>[];
    for (final transaction in tables['transactions'] ?? const <Map<String, dynamic>>[]) {
      final attachmentPath = transaction['attachment_path']?.toString() ?? '';
      final attachmentFile = File(attachmentPath);
      if (attachmentPath.isNotEmpty && await attachmentFile.exists()) {
        attachments.add({
          'transaction_id': transaction['id'],
          'file_name': basename(attachmentPath),
          'base64': base64Encode(await attachmentFile.readAsBytes()),
        });
      }
    }
    final backup = {
      'format': _format,
      'version': _version,
      'created_at': DateTime.now().toIso8601String(),
      'tables': tables,
      'logo_base64': logoBase64,
      'logo_extension': logoExtension,
      'transaction_attachments': attachments,
    };
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)));
  }

  static Future<String?> createBackup() async {
    final fileName = 'business-manager-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    final savedPath = await ExportFileService.saveBytes(
      suggestedName: fileName,
      bytes: await createBackupBytes(),
      mimeType: 'application/json',
      title: 'Save BizRise backup',
    );
    if (savedPath == null) return null;
    await DatabaseHelper.instance.setAppSetting('last_backup_at', DateTime.now().toIso8601String());
    return savedPath;
  }

  static Future<bool> shareBackup() async {
    final fileName = 'business-manager-backup-${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    final shared = await ExportFileService.shareBytes(
      fileName: fileName,
      bytes: await createBackupBytes(),
      mimeType: 'application/json',
      title: 'Share BizRise backup',
    );
    if (shared) {
      await DatabaseHelper.instance.setAppSetting('last_backup_at', DateTime.now().toIso8601String());
    }
    return shared;
  }

  static Future<void> restoreBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'BizRise backup', extensions: ['json']),
      ],
    );
    if (file == null) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map ||
        decoded['format'] != _format ||
        decoded['tables'] is! Map) {
      throw const FormatException('This is not a valid BizRise backup file.');
    }

    final tables = Map<String, dynamic>.from(decoded['tables'] as Map);
    await DatabaseHelper.instance.restoreBackupData(tables);

    final logoBase64 = decoded['logo_base64']?.toString();
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      final logoExtension = decoded['logo_extension']?.toString() ?? '.png';
      final directory = await databaseFactory.getDatabasesPath();
      final logoPath = join(directory, 'business_manager_logo$logoExtension');
      await File(logoPath).writeAsBytes(base64Decode(logoBase64));
      await DatabaseHelper.instance.updateBusinessLogoPath(logoPath);
    } else {
      await DatabaseHelper.instance.updateBusinessLogoPath('');
    }

    final attachments = decoded['transaction_attachments'];
    if (attachments is List) {
      final directory = Directory(
        join(
          await databaseFactory.getDatabasesPath(),
          'transaction_attachments',
        ),
      );
      await directory.create(recursive: true);
      final db = await DatabaseHelper.instance.database;
      for (final item in attachments) {
        if (item is! Map) continue;
        final transactionId = item['transaction_id'];
        final base64 = item['base64']?.toString();
        if (transactionId is! int || base64 == null || base64.isEmpty) continue;
        final safeName = basename(
          item['file_name']?.toString() ?? 'bill_$transactionId.jpg',
        );
        final path = join(
          directory.path,
          '${DateTime.now().microsecondsSinceEpoch}_$safeName',
        );
        await File(path).writeAsBytes(base64Decode(base64));
        await db.update(
          'transactions',
          {'attachment_path': path},
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      }
    }
  }
}
