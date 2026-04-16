import 'dart:async';
import '../models/conversion_task.dart';
import '../services/notification_service.dart';
import 'ffmpeg_service.dart';
import 'storage_service.dart';
import '../utils/app_logger.dart';

class ConversionService {
  final List<ConversionTask> _tasks = [];
  final StreamController<List<ConversionTask>> _tasksController =
      StreamController<List<ConversionTask>>.broadcast();

  Stream<List<ConversionTask>> get tasksStream => _tasksController.stream;
  List<ConversionTask> get tasks => List.unmodifiable(_tasks);

  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();

  // Notification IDs
  static const int _notificationIdSuccess = 2;
  static const int _notificationIdError = 3;

  Future<void> convertFile(
    String inputPath, {
    required String format,
    String bitrate = '192k',
    Duration? start,
    Duration? end,
    Function(ConversionTask)? onProgress,
  }) async {
    // Generate output path first to ensure the directory exists
    final outputPath = await _storageService.getOutputPath(
      inputPath,
      format,
      bitrate,
      mediaType: 'Music',
    );

    final task = ConversionTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputPath: inputPath,
      outputPath: outputPath,
      format: format,
      bitrate: bitrate,
      startTime: start,
      endTime: end,
      progress: 0,
      status: ConversionStatus.queued,
    );

    _addTask(task);

    try {
      final success = await FFMpegService.convertAudio(
        inputPath: inputPath,
        outputPath: outputPath,
        format: format,
        bitrate: bitrate,
        start: start,
        end: end,
        onProgress: (progress) {
          task.progress = (progress * 100).toInt();
          task.status = ConversionStatus.converting;
          _updateTask(task);
          onProgress?.call(task);
        },
        onLog: (log) => AppLogger.info('FFmpeg: $log'),
      );

      if (!success) {
        throw Exception('Conversion failed');
      }

      // Update task on success
      task.outputPath = outputPath;
      task.progress = 100;
      task.status = ConversionStatus.completed;
      _updateTask(task);
      onProgress?.call(task);

      // Show success notification
      await _showSuccessNotification(outputPath, format);
    } catch (e, stackTrace) {
      AppLogger.error('Error during conversion', e, stackTrace);

      // Update task on failure
      task.status = ConversionStatus.failed;
      task.error = e.toString();
      _updateTask(task);

      // Show error notification
      await _showErrorNotification(e.toString());

      rethrow;
    }
  }

  Future<void> convertAudioOrVideo(
    String inputPath, {
    required String format,
    required String type, // 'audio' or 'video'
    String bitrate = '192k',
  }) async {
    final outputPath = await _storageService.getOutputPath(
      inputPath,
      format,
      type == 'video' ? 'video' : bitrate,
      mediaType: type == 'video' ? 'Movies' : 'Music',
    );

    final task = ConversionTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputPath: inputPath,
      outputPath: outputPath,
      format: format,
      bitrate: type == 'video' ? 'auto' : bitrate,
      progress: 0,
      status: ConversionStatus.queued,
    );

    _addTask(task);

    try {
      bool success;
      if (type == 'video') {
         success = await FFMpegService.convertVideo(
          inputPath: inputPath,
          outputPath: outputPath,
          format: format,
          onProgress: (progress) {
            task.progress = (progress * 100).toInt();
            task.status = ConversionStatus.converting;
            _updateTask(task);
          },
          onLog: (log) => AppLogger.info('FFmpeg Video: $log'),
        );
      } else {
        success = await FFMpegService.convertAudio(
          inputPath: inputPath,
          outputPath: outputPath,
          format: format,
          bitrate: bitrate,
          onProgress: (progress) {
            task.progress = (progress * 100).toInt();
            task.status = ConversionStatus.converting;
            _updateTask(task);
          },
          onLog: (log) => AppLogger.info('FFmpeg Audio: $log'),
        );
      }

      if (!success) {
        throw Exception('Conversion failed');
      }

      task.outputPath = outputPath;
      task.progress = 100;
      task.status = ConversionStatus.completed;
      _updateTask(task);

      await _showSuccessNotification(outputPath, format);
    } catch (e) {
      task.status = ConversionStatus.failed;
      task.error = e.toString();
      _updateTask(task);
      await _showErrorNotification(e.toString());
      rethrow;
    }
  }

  Future<void> compressVideo(
    String inputPath, {
    required String resolution,
    required String crf,
  }) async {
    final outputPath = await _storageService.getOutputPath(
      inputPath,
      'mp4',
      'compressed_$resolution',
      mediaType: 'Movies',
    );

    final task = ConversionTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputPath: inputPath,
      outputPath: outputPath,
      format: 'mp4 (compressed)',
      bitrate: 'crf $crf',
      progress: 0,
      status: ConversionStatus.queued,
    );

    _addTask(task);

    try {
      final success = await FFMpegService.compressVideo(
        inputPath: inputPath,
        outputPath: outputPath,
        resolution: resolution,
        crf: crf,
        onProgress: (progress) {
          task.progress = (progress * 100).toInt();
          task.status = ConversionStatus.converting;
          _updateTask(task);
        },
        onLog: (log) => AppLogger.info('FFmpeg Compress: $log'),
      );

      if (!success) {
        throw Exception('Compression failed');
      }

      task.outputPath = outputPath;
      task.progress = 100;
      task.status = ConversionStatus.completed;
      _updateTask(task);

      await _showSuccessNotification(outputPath, 'compressed mp4');
    } catch (e) {
      task.status = ConversionStatus.failed;
      task.error = e.toString();
      _updateTask(task);
      await _showErrorNotification(e.toString());
      rethrow;
    }
  }

  Future<void> _showSuccessNotification(
    String outputPath,
    String format,
  ) async {
    try {
      await _notificationService.showCompletionNotification(
        id: _notificationIdSuccess,
        title: 'Konversi Selesai',
        body: 'Video berhasil dikonversi ke ${format.toUpperCase()}',
        payload: null, // Disable click action
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to show success notification', e, stackTrace);
      // Don't rethrow - notification failure shouldn't fail the conversion
    }
  }

  Future<void> _showErrorNotification(String error) async {
    try {
      await _notificationService.showErrorNotification(
        id: _notificationIdError,
        title: 'Konversi Gagal',
        error: error,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to show error notification', e, stackTrace);
      // Don't rethrow - notification failure shouldn't fail the conversion
    }
  }

  void _addTask(ConversionTask task) {
    _tasks.insert(0, task); // Add new task at the beginning
    _notifyListeners();
  }

  void _updateTask(ConversionTask task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      _notifyListeners();
    }
  }

  void _notifyListeners() {
    if (!_tasksController.isClosed) {
      _tasksController.add(List<ConversionTask>.from(_tasks));
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((task) => task.id == taskId);
    _notifyListeners();
  }

  void dispose() {
    _tasksController.close();
  }
}
