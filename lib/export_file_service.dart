import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show getSaveLocation;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

/// Saves a generated file using the native experience for each platform.
///
/// `file_selector` provides a Save As dialog on desktop, but Android and iOS
/// do not implement that API. Android uses the system document picker so the
/// user can select a folder directly; iOS uses the system share sheet.
class ExportFileService {
  static const _androidSaveChannel = MethodChannel('bizrise/file_save');


  static Future<String?> saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
    String? title,
  }) async {
    if (Platform.isAndroid) {
      final temporaryDirectory = await getTemporaryDirectory();
      final file = File(path.join(temporaryDirectory.path, suggestedName));
      await file.writeAsBytes(bytes, flush: true);
      final savedUri = await _androidSaveChannel.invokeMethod<String>('saveFile', {
        'filePath': file.path,
        'suggestedName': suggestedName,
        'mimeType': mimeType,
      });
      return savedUri == null ? null : suggestedName;
    }
    if (Platform.isIOS) {
      final temporaryDirectory = await getTemporaryDirectory();
      final file = File(path.join(temporaryDirectory.path, suggestedName));
      await file.writeAsBytes(bytes, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          title: title ?? suggestedName,
          subject: suggestedName,
          files: [XFile(file.path, mimeType: mimeType)],
          fileNameOverrides: [suggestedName],
        ),
      );
      return result.status == ShareResultStatus.dismissed ? null : suggestedName;
    }
    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  static Future<bool> shareBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? title,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final file = File(path.join(temporaryDirectory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title ?? fileName,
        subject: fileName,
        files: [XFile(file.path, mimeType: mimeType)],
        fileNameOverrides: [fileName],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  static Future<String?> saveText({
    required String suggestedName,
    required String contents,
    required String title,
  }) async {
    if (Platform.isAndroid) {
      final temporaryDirectory = await getTemporaryDirectory();
      final file = File(path.join(temporaryDirectory.path, suggestedName));
      await file.writeAsString(contents);

      final savedUri = await _androidSaveChannel
          .invokeMethod<String>('saveFile', {
            'filePath': file.path,
            'suggestedName': suggestedName,
            'mimeType': _mimeTypeFor(suggestedName),
          });
      return savedUri == null ? null : suggestedName;
    }

    if (Platform.isIOS) {
      final temporaryDirectory = await getTemporaryDirectory();
      final file = File(path.join(temporaryDirectory.path, suggestedName));
      await file.writeAsString(contents);

      final result = await SharePlus.instance.share(
        ShareParams(
          title: title,
          subject: suggestedName,
          files: [XFile(file.path)],
          fileNameOverrides: [suggestedName],
        ),
      );
      return result.status == ShareResultStatus.dismissed
          ? null
          : suggestedName;
    }

    final location = await getSaveLocation(suggestedName: suggestedName);
    if (location == null) return null;
    await File(location.path).writeAsString(contents);
    return location.path;
  }

  static String _mimeTypeFor(String fileName) {
    if (fileName.toLowerCase().endsWith('.csv')) return 'text/csv';
    if (fileName.toLowerCase().endsWith('.json')) return 'application/json';
    return 'application/octet-stream';
  }
}
