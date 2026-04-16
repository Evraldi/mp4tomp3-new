import 'dart:io' show Platform, Directory, File;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../utils/app_logger.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  Directory? _cachedOutputDirectory;

  factory StorageService() => _instance;
  StorageService._internal();

  Future<Directory> getAppDocumentsDirectory(String mediaType) async {
    try {
      Directory? baseDir;
      String folderName = 'MP4ToMP3';

      if (Platform.isAndroid) {
        // Request MANAGE_EXTERNAL_STORAGE specifically for system folders access if needed
        // but for now we try to use the public paths directly.
        if (await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted) {
           baseDir = Directory('/storage/emulated/0/$mediaType');
        } else {
           // Fallback if permissions not granted yet
           baseDir = await getExternalStorageDirectory();
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final directory = Directory('${baseDir?.path ?? ""}/$folderName');
      AppLogger.debug('Output directory for $mediaType: ${directory.path}');

      if (!await directory.exists()) {
        AppLogger.info('Creating directory: ${directory.path}');
        await directory.create(recursive: true);
      }

      return directory;
    } catch (e, stackTrace) {
      AppLogger.error('Error accessing storage directory for $mediaType', e, stackTrace);
      rethrow;
    }
  }

  Future<String> getOutputPath(
    String inputPath,
    String format,
    String bitrate, {
    String mediaType = 'Music',
  }) async {
    final dir = await getAppDocumentsDirectory(mediaType);
    final baseName = path.basenameWithoutExtension(inputPath);
    // Sanitize baseName and bitrate for filename safety
    final cleanBaseName = baseName.replaceAll(RegExp(r'[^\w\s-]'), '');
    final cleanBitrate = bitrate.replaceAll(RegExp(r'[^\w\s-]'), '');
    
    return '${dir.path}/${cleanBaseName}_${cleanBitrate}.$format';
  }

  Future<bool> requestFullStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> openFileDirectory(String filePath) async {
    // Redirect to openFile because opening directories is too restricted on modern Android
    return openFile(filePath);
  }

  Future<void> openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File tidak ditemukan: $filePath');
      }

      AppLogger.debug('Opening file: $filePath');
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in openFile', e, stackTrace);
      rethrow;
    }
  }
}
