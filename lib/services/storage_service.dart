import 'dart:io' show Platform, Directory, File, FileSystemEntity;
import 'package:path/path.dart' as path;
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

  Future<Directory> getAppDocumentsDirectory() async {
    if (_cachedOutputDirectory != null) return _cachedOutputDirectory!;

    try {
      final directory = Directory('/storage/emulated/0/Music/MP4ToMP3');
      AppLogger.debug('Checking directory: ${directory.path}');

      if (!await Permission.storage.isGranted) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Izin penyimpanan tidak diberikan');
        }
      }

      if (!await directory.exists()) {
        AppLogger.info('Creating directory: ${directory.path}');
        await directory.create(recursive: true);
      }

      _cachedOutputDirectory = directory;
      return directory;
    } catch (e, stackTrace) {
      AppLogger.error('Error accessing app documents directory', e, stackTrace);
      rethrow;
    }
  }

  Future<String> getOutputPath(
    String inputPath,
    String format,
    String bitrate,
  ) async {
    final dir = await getAppDocumentsDirectory();
    final baseName = path.basenameWithoutExtension(inputPath);
    final qualitySuffix = ' ($bitrate)';
    return '${dir.path}/$baseName$qualitySuffix.$format';
  }

  Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Gagal membuka file');
      }
    } catch (e) {
      AppLogger.error('Error opening file', e);
      rethrow;
    }
  }

  Future<void> openFileDirectory(String filePath) async {
    try {
      final directory = path.dirname(filePath);
      AppLogger.debug('Opening directory: $directory');

      if (Platform.isAndroid) {
        try {
          // Try using OpenFilex first
          final result = await OpenFilex.open(
            directory,
            type: 'resource/folder',
            uti: 'public.folder',
          );

          if (result.type != ResultType.done) {
            // Fallback to using the system's file manager
            final intent = AndroidIntent(
              action: 'android.intent.action.VIEW',
              data: Uri.file(directory).toString(),
              type: 'resource/folder',
              flags: <int>[
                Flag.FLAG_ACTIVITY_NEW_TASK,
                Flag.FLAG_GRANT_READ_URI_PERMISSION,
              ],
            );
            await intent.launch();
          }
        } catch (e) {
          AppLogger.error('Error opening directory', e);
          // Final fallback - try to open the parent directory
          final parentDir = Directory(directory).parent;
          if (await parentDir.exists()) {
            await OpenFilex.open(
              parentDir.path,
              type: 'resource/folder',
              uti: 'public.folder',
            );
          }
        }
      } else {
        // Platform non Android
        final result = await OpenFilex.open(
          directory,
          type: 'resource/folder',
          uti: 'public/folder',
        );
        if (result.type != ResultType.done) {
          throw Exception('Gagal membuka direktori');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in openFileDirectory', e, stackTrace);
      rethrow;
    }
  }
}
