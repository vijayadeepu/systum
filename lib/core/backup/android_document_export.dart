import 'package:flutter/services.dart';

import 'export_service.dart';

/// Android SAF bridge. file_selector_android does not implement save-document
/// selection in the supported plugin version, so Android uses ACTION_CREATE_DOCUMENT.
final class AndroidDocumentExport {
  AndroidDocumentExport({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.systum.app/backup_export');

  final MethodChannel _channel;

  Future<String?> selectDestination(String fileName) {
    return _channel.invokeMethod<String>('selectDocument', {
      'fileName': fileName,
    });
  }

  Future<void> publish(List<int> bytes, String destination) {
    return _channel.invokeMethod<void>('writeDocument', {
      'uri': destination,
      'bytes': Uint8List.fromList(bytes),
    });
  }

  Future<ExportReadback> readBack(String destination) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('readDocument', {
        'uri': destination,
      });
      if (bytes == null) return const ExportReadback.failed('Empty readback.');
      return ExportReadback.available(bytes);
    } on PlatformException catch (error) {
      if (error.code == 'readback_unavailable') {
        return const ExportReadback.unavailable();
      }
      return ExportReadback.failed(error.message ?? error.code);
    }
  }
}

final class AndroidExportPublisher implements ExportPublisher {
  AndroidExportPublisher({AndroidDocumentExport? bridge})
    : _bridge = bridge ?? AndroidDocumentExport();

  final AndroidDocumentExport _bridge;

  @override
  Future<void> publish(List<int> bytes, String destination) {
    return _bridge.publish(bytes, destination);
  }

  @override
  Future<ExportReadback> readBack(String destination) {
    return _bridge.readBack(destination);
  }
}
