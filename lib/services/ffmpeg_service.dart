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
}
