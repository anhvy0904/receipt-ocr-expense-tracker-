import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ReceiptImageService {
  ReceiptImageService({
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory> Function() _documentsDirectoryProvider;

  /// Delete a committed receipt file, tolerating absent files and null paths.
  Future<void> deleteStoredReceipt(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final file = File(imagePath);
    if (!await file.exists()) return;
    final documents = await _documentsDirectoryProvider();
    if (!path.isWithin(
      path.absolute(documents.path),
      path.absolute(imagePath),
    )) {
      throw ArgumentError('Receipt image is outside application documents');
    }
    try {
      await file.delete();
    } on FileSystemException {
      if (await file.exists()) rethrow;
    }
    final parent = file.parent;
    if (path.equals(
          path.absolute(parent.parent.path),
          path.absolute(documents.path),
        ) &&
        path.basename(parent.path).startsWith('receipt_') &&
        await parent.exists() &&
        await parent.list().isEmpty) {
      await parent.delete();
    }
  }

  /// Unique directory and filename prevent overwriting an existing receipt.
  /// The source remains intact even if copy or later database insertion fails.
  Future<String> copyToDocuments(String sourcePath) async {
    final documents = await _documentsDirectoryProvider();
    await documents.create(recursive: true);
    final directory = await documents.createTemp(
      'receipt_${DateTime.now().microsecondsSinceEpoch}_',
    );
    final destination = path.join(
      directory.path,
      '${path.basename(directory.path)}.jpg',
    );
    try {
      await File(sourcePath).copy(destination);
      return destination;
    } catch (_) {
      try {
        await discardDocumentCopy(destination);
      } catch (_) {
        /* Preserve the original copy error. */
      }
      rethrow;
    }
  }

  /// Called only for an uncommitted copy made by copyToDocuments.
  Future<void> discardDocumentCopy(String imagePath) async {
    final documents = await _documentsDirectoryProvider();
    final file = File(imagePath);
    if (!path.equals(
          path.absolute(file.parent.parent.path),
          path.absolute(documents.path),
        ) ||
        !path.basename(file.parent.path).startsWith('receipt_') ||
        path.basename(file.path) != '${path.basename(file.parent.path)}.jpg') {
      throw ArgumentError('Image is outside a receipt directory');
    }
    if (await file.exists()) await file.delete();
    if (await file.parent.exists() && await file.parent.list().isEmpty) {
      await file.parent.delete();
    }
  }

  Future<String> createTemporaryReceiptPath() async {
    final temporary = await _temporaryDirectoryProvider();
    final scan = await temporary.createTemp('receiptwise_scan_');
    return path.join(scan.path, 'receipt.jpg');
  }

  Future<void> discardTemporaryPhoto(String temporaryPath) async {
    final file = File(temporaryPath);
    if (await file.exists()) await file.delete();
    // Remove only our own isolated scan directory, never the camera cache root.
    final parent = file.parent;
    if (path.basename(parent.path).startsWith('receiptwise_scan_') &&
        path.basename(file.path) == 'receipt.jpg') {
      final temporary = await _temporaryDirectoryProvider();
      if (path.equals(
            path.absolute(parent.parent.path),
            path.absolute(temporary.path),
          ) &&
          await parent.exists() &&
          await parent.list().isEmpty) {
        await parent.delete();
      }
    }
  }
}
