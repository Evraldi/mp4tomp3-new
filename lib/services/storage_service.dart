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
        throw Exception('File not found: $filePath');
      }

      String? mimeType;
      final ext = path.extension(filePath).toLowerCase();
      if (['.jpg', '.jpeg'].contains(ext)) mimeType = 'image/jpeg';
      else if (ext == '.png') mimeType = 'image/png';
      else if (ext == '.webp') mimeType = 'image/webp';
      else if (ext == '.gif') mimeType = 'image/gif';
      else if (ext == '.bmp') mimeType = 'image/bmp';
      else if (ext == '.mp4') mimeType = 'video/mp4';
      else if (ext == '.mkv') mimeType = 'video/x-matroska';
      else if (ext == '.avi') mimeType = 'video/x-msvideo';
      else if (ext == '.mp3') mimeType = 'audio/mpeg';
      else if (ext == '.m4a') mimeType = 'audio/mp4';
      else if (ext == '.wav') mimeType = 'audio/x-wav';
      else if (ext == '.ogg') mimeType = 'audio/ogg';

      AppLogger.debug('Opening file: $filePath with mimeType: $mimeType');
      
      if (Platform.isAndroid && filePath.startsWith('/storage/emulated/0/')) {
        final relativePath = filePath.replaceFirst('/storage/emulated/0/', '');
        final contentUri = 'content://com.example.mp4tomp3.fileProvider/external_storage/$relativePath';
        
        final intent = AndroidIntent(
          action: 'action_view',
          data: contentUri,
          type: mimeType,
          flags: <int>[
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
            Flag.FLAG_ACTIVITY_NEW_TASK,
          ],
        );
        
        try {
          await intent.launch();
          AppLogger.debug('Launched intent successfully via android_intent_plus');
          return;
        } catch (e) {
          AppLogger.error('Failed to launch manual intent', e, null);
          // Fallback to open_filex if it fails
        }
      }

      final result = mimeType != null 
          ? await OpenFilex.open(filePath, type: mimeType)
          : await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in openFile', e, stackTrace);
      rethrow;
    }
  }

  Future<List<File>> getAllConvertedFiles() async {
    List<File> allFiles = [];
    final mediaTypes = ['Music', 'Movies', 'Pictures'];
    
    for (var type in mediaTypes) {
      try {
        final dir = await getAppDocumentsDirectory(type);
        if (await dir.exists()) {
          final files = dir.listSync().whereType<File>().toList();
          allFiles.addAll(files);
        }
      } catch (e) {
        AppLogger.error('Error reading dir $type', e, null);
      }
    }
    
    // Sort by modified time descending (newest first)
    allFiles.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    return allFiles;
  }
}

