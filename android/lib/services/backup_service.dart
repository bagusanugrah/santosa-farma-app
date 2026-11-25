import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'supabase_service.dart';

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  Future<File> createBackupZip() async {
    final backupData = await SupabaseService.instance.exportBackupData();
    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
    final jsonBytes = utf8.encode(jsonString);

    // Create Archive
    final archive = Archive();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final jsonFileName = 'apotek_santosa_farma_backup_$dateStr.json';

    archive.addFile(ArchiveFile(jsonFileName, jsonBytes.length, jsonBytes));

    // Masukkan seluruh gambar produk yang aktif ke dalam ZIP cadangan
    final products = (backupData['data']?['products'] as List?) ?? [];
    final downloadedFiles = <String>{};

    for (final p in products) {
      final imgPath = p['image'] as String?;
      final fileName = SupabaseService.instance.extractStorageFileName(imgPath);
      if (fileName != null && fileName.isNotEmpty && !downloadedFiles.contains(fileName)) {
        downloadedFiles.add(fileName);
        try {
          final imgBytes = await SupabaseService.instance.downloadProductImage(fileName);
          if (imgBytes != null && imgBytes.isNotEmpty) {
            archive.addFile(ArchiveFile('images/$fileName', imgBytes.length, imgBytes));
            debugPrint('[Backup ZIP] Berhasil mengemas gambar: images/$fileName (${imgBytes.length} bytes)');
          }
        } catch (e) {
          debugPrint('[Backup ZIP] Gagal mendownload gambar $fileName untuk backup: $e');
        }
      }
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final dir = await getApplicationDocumentsDirectory();
    final zipFile = File('${dir.path}/backup_santosa_farma_$dateStr.zip');
    await zipFile.writeAsBytes(zipBytes ?? []);

    return zipFile;
  }

  Future<void> shareBackupZip() async {
    final zipFile = await createBackupZip();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zipFile.path)],
        text: 'Cadangan Database Apotek Santosa Farma (${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())})',
        subject: 'Backup Database Santosa Farma',
      ),
    );
  }

  Future<int?> restoreFromPicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final filePath = result.files.single.path!;
    final file = File(filePath);

    Map<String, dynamic>? backupJson;
    final Map<String, Uint8List> images = {};

    if (filePath.endsWith('.zip')) {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final archFile in archive) {
        if (archFile.isFile) {
          if (archFile.name.endsWith('.json')) {
            final content = utf8.decode(archFile.content as List<int>);
            backupJson = jsonDecode(content);
          } else if (archFile.name.startsWith('images/')) {
            final imgName = archFile.name.replaceFirst('images/', '');
            if (imgName.isNotEmpty && !imgName.startsWith('.')) {
              images[imgName] = Uint8List.fromList(archFile.content as List<int>);
              debugPrint('[Restore ZIP] Ekstraksi gambar: $imgName (${images[imgName]!.length} bytes)');
            }
          }
        }
      }
    } else {
      final content = await file.readAsString();
      backupJson = jsonDecode(content);
    }

    if (backupJson == null || backupJson['data'] == null) {
      throw Exception('Format file backup tidak valid.');
    }

    final cleanedCount = await SupabaseService.instance.restoreBackupData(
      backupJson,
      images: images,
    );

    return cleanedCount;
  }
}
