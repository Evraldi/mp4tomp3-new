import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FFMpegService {
  static Future<bool> convertAudio({
    required String inputPath,
    required String outputPath,
    required String format,
    required String bitrate,
    required Function(double progress) onProgress,
    required Function(String log) onLog,
    Duration? start,
    Duration? end,
  }) async {
    try {
      String command;
      String durationArgs = '';

      // Add duration parameters if provided
      if (start != null || end != null) {
        final startTime = start != null ? start.inMilliseconds / 1000.0 : 0;
        final endTime = end != null ? end.inMilliseconds / 1000.0 : null;

        if (endTime != null) {
          durationArgs = '-ss $startTime -to $endTime';
        } else {
          durationArgs = '-ss $startTime';
        }
      }

      // Build the appropriate FFmpeg command based on the output format
      switch (format.toLowerCase()) {
        case 'mp3':
          command =
              '-y $durationArgs -i "$inputPath" -vn -ar 44100 -ac 2 -b:a $bitrate -f mp3 "$outputPath"';
          break;
        case 'm4a': // AAC format
          command =
              '-y $durationArgs -i "$inputPath" -vn -c:a aac -b:a $bitrate -f mp4 "$outputPath"';
          break;
        case 'wav':
          // For WAV, we don't use bitrate as it's typically uncompressed
          command =
              '-y $durationArgs -i "$inputPath" -vn -ar 44100 -ac 2 -codec:a pcm_s16le -f wav "$outputPath"';
          break;
        case 'ogg':
          command =
              '-y $durationArgs -i "$inputPath" -vn -c:a libvorbis -b:a $bitrate -f ogg "$outputPath"';
          break;
        default:
          onLog('Unsupported format: $format');
          return false;
      }

      onLog('Executing FFmpeg command: $command');
      final completer = Completer<bool>();

      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          final success = ReturnCode.isSuccess(returnCode);
          if (!success) {
            final failStackTrace = await session.getFailStackTrace();
            onLog('FFmpeg execution failed: ${await session.getOutput()}');
            if (failStackTrace != null) {
              onLog('Stack trace: $failStackTrace');
            }
          }
          completer.complete(success);
        },
        (log) => onLog(log.getMessage()),
        (statistics) {
          final duration = statistics.getTime();
          if (duration > 0) {
            // Estimate progress based on time (30 seconds max duration for estimation)
            final progress = (duration / 30000.0).clamp(0.0, 1.0);
            onProgress(progress);
          }
        },
      );

      return await completer.future;
    } catch (e, stackTrace) {
      onLog('Error during conversion: $e\n$stackTrace');
      return false;
    }
  }

  static Future<bool> convertVideo({
    required String inputPath,
    required String outputPath,
    required String format,
    required Function(double progress) onProgress,
    required Function(String log) onLog,
  }) async {
    try {
      String command = '-y -i "$inputPath" ';
      
      switch (format.toLowerCase()) {
        case 'mkv':
          // Using copy codecs for MKV is fast but might fail if input isn't compatible with MKV
          // We'll use more generic ones for better compatibility
          command += '-c:v libx264 -preset superfast -c:a aac "$outputPath"';
          break;
        case 'avi':
          command += '-c:v mpeg4 -c:a mp3 "$outputPath"';
          break;
        case 'mp4':
        default:
          command += '-c:v libx264 -preset superfast -c:a aac "$outputPath"';
          break;
      }

      onLog('Executing Video Convert: $command');
      return await _executeCommand(command, onProgress, onLog);
    } catch (e, stackTrace) {
      onLog('Error during video conversion: $e\n$stackTrace');
      return false;
    }
  }

  static Future<bool> compressVideo({
    required String inputPath,
    required String outputPath,
    required String resolution,
    required String crf,
    required Function(double progress) onProgress,
    required Function(String log) onLog,
  }) async {
    try {
      // Use scale filter correctly and ensure it is divisible by 2 for x264
      final command = '-y -i "$inputPath" -vf "scale=$resolution:force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2:(ow-iw)/2:(oh-ih)/2" -vcodec libx264 -preset superfast -crf $crf -acodec aac "$outputPath"';
      onLog('Executing Video Compress: $command');
      return await _executeCommand(command, onProgress, onLog);
    } catch (e, stackTrace) {
      onLog('Error during video compression: $e\n$stackTrace');
      return false;
    }
  }

  static Future<bool> _executeCommand(
    String command, 
    Function(double progress) onProgress, 
    Function(String log) onLog
  ) async {
    final completer = Completer<bool>();
    await FFmpegKit.executeAsync(
      command,
      (session) async {
        final returnCode = await session.getReturnCode();
        final success = ReturnCode.isSuccess(returnCode);
        if (!success) {
          final output = await session.getOutput();
          onLog('FFmpeg failed with code: $returnCode');
          onLog('FFmpeg Output Summary: $output');
          
          final failStackTrace = await session.getFailStackTrace();
          if (failStackTrace != null) {
            onLog('Stack trace: $failStackTrace');
          }
        }
        completer.complete(success);
      },
      (log) => onLog(log.getMessage()),
      (statistics) {
        final duration = statistics.getTime();
        // Since we don't grab total video duration first in these simple implementations,
        // we'll just track if there is progress
        if (duration > 0) {
           final progress = (duration / 60000.0).clamp(0.0, 1.0); // Rough estimate assuming 1min max
           onProgress(progress);
        }
      },
    );
    return await completer.future;
  }

  static Future<String> getFFmpegVersion() async {
    try {
      final session = await FFmpegKit.execute('-version');
      final output = await session.getOutput();

      if (output == null) return 'No output';

      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        return 'Failed to get version';
      }

      final lines = output.split('\n');
      return lines.firstWhere(
        (line) => line.startsWith('ffmpeg version'),
        orElse: () => 'Unknown version',
      );
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<bool> generateThumbnail(String videoPath, String outputPath) async {
    try {
      // Attempt to take a frame at 1 second for a meaningful preview
      // -y to overwrite if exists
      // -vframes 1 to capture only one frame
      final command = '-y -i "$videoPath" -ss 00:00:01 -vframes 1 "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        return true;
      }
      
      // Fallback: if 1 second is too far (short video), try 0
      final fallbackCommand = '-y -i "$videoPath" -ss 00:00:00 -vframes 1 "$outputPath"';
      final fallbackSession = await FFmpegKit.execute(fallbackCommand);
      final fallbackReturnCode = await fallbackSession.getReturnCode();
      return ReturnCode.isSuccess(fallbackReturnCode);
    } catch (e) {
      return false;
    }
  }
}
