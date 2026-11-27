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

  Future<({Uint8List bytes, String fileName})> _buildBackupZipBytes() async {
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
    final zipBytes = Uint8List.fromList(zipEncoder.encode(archive) ?? []);
    return (bytes: zipBytes, fileName: 'backup_santosa_farma_$dateStr.zip');
  }

  Future<File> createBackupZip() async {
    final bundle = await _buildBackupZipBytes();
    final dir = await getApplicationDocumentsDirectory();
    final zipFile = File('${dir.path}/${bundle.fileName}');
    await zipFile.writeAsBytes(bundle.bytes);
    return zipFile;
  }

  /// Membuka File Manager sistem Android (default Download) untuk menyimpan file ZIP backup
  /// sehingga pengguna tetap bisa mengganti folder penyimpanan bila diinginkan.
  Future<String?> saveBackupZipWithPicker() async {
    final bundle = await _buildBackupZipBytes();
    return FilePicker.saveFile(
      dialogTitle: 'Simpan Backup Database',
      fileName: bundle.fileName,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bundle.bytes,
    );
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

  static final RegExp _backupJsonNamePattern =
      RegExp(r'^apotek_santosa_farma_backup_\d{8}_\d{6}\.json$');

  Future<int?> restoreFromPicker() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      return null;
    }

    final filePath = result.files.single.path!;
    final lowerPath = filePath.toLowerCase();
    if (!lowerPath.endsWith('.zip') && !lowerPath.endsWith('.json')) {
      throw Exception('Ekstensi file tidak didukung. Pilih file .zip atau .json hasil backup resmi.');
    }

    final file = File(filePath);
    Map<String, dynamic>? backupJson;
    final Map<String, Uint8List> images = {};

    if (lowerPath.endsWith('.zip')) {
      final bytes = await file.readAsBytes();
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        throw Exception('File ZIP rusak atau bukan arsip ZIP yang valid.');
      }

      int jsonFileCount = 0;
      for (final archFile in archive) {
        if (!archFile.isFile) continue;

        final entryName = archFile.name.replaceAll('\\', '/');
        if (_backupJsonNamePattern.hasMatch(entryName)) {
          jsonFileCount++;
          if (jsonFileCount > 1) {
            throw Exception('Arsip ZIP tidak valid: terdapat lebih dari satu file JSON backup.');
          }
          try {
            final content = utf8.decode(archFile.content as List<int>);
            final decoded = jsonDecode(content);
            if (decoded is! Map<String, dynamic>) {
              throw Exception('Format isi JSON di dalam ZIP tidak valid.');
            }
            backupJson = decoded;
          } catch (e) {
            if (e is Exception) rethrow;
            throw Exception('Gagal membaca data JSON di dalam file ZIP backup.');
          }
        } else if (entryName.startsWith('images/')) {
          final imgName = entryName.substring('images/'.length);
          final hasInvalidSegment = imgName.isEmpty ||
              imgName.contains('/') ||
              imgName.contains('..') ||
              imgName.startsWith('.');
          if (hasInvalidSegment) {
            throw Exception('Struktur folder gambar di dalam ZIP tidak valid: $entryName');
          }
          images[imgName] = Uint8List.fromList(archFile.content as List<int>);
          debugPrint('[Restore ZIP] Ekstraksi gambar: $imgName (${images[imgName]!.length} bytes)');
        } else {
          throw Exception('File tidak dikenal di dalam arsip ZIP: $entryName. Gunakan ZIP hasil export resmi.');
        }
      }

      if (jsonFileCount != 1 || backupJson == null) {
        throw Exception('Arsip ZIP bukan file backup resmi Apotek Santosa Farma (file JSON backup tidak ditemukan).');
      }
    } else {
      try {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Format file JSON tidak valid.');
        }
        backupJson = decoded;
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('File JSON rusak atau tidak dapat dibaca.');
      }
    }

    // Validasi skema & header lengkap sebelum menyentuh storage / database
    try {
      SupabaseService.instance.validateBackupPayload(backupJson);
    } on FormatException catch (e) {
      throw Exception(e.message);
    }

    final cleanedCount = await SupabaseService.instance.restoreBackupData(
      backupJson,
      images: images,
    );

    return cleanedCount;
  }
}
