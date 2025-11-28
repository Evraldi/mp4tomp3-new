import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

enum MP3Quality {
  low(bitrate: '96k', name: 'Low (96kbps)'),
  medium(bitrate: '192k', name: 'Medium (192kbps)'),
  high(bitrate: '320k', name: 'High (320kbps)');

  final String bitrate;
  final String name;

  const MP3Quality({required this.bitrate, required this.name});
}

class FileService {
  static Future<String> getOutputPath(String inputPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${path.basenameWithoutExtension(inputPath)}.mp3';
    return '${appDir.path}/$fileName';
  }

  static Future<void> ensureDirectoryExists(String filePath) async {
    final directory = Directory(path.dirname(filePath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  static Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  static Future<void> deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
