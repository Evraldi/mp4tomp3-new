enum ConversionStatus { queued, converting, completed, failed }

class ConversionTask {
  final String id;
  final String inputPath;
  String outputPath;
  final String format;
  final String bitrate;
  final Duration? startTime;
  final Duration? endTime;
  int progress;
  ConversionStatus status;
  String? error;
  DateTime? startedAt;
  DateTime? completedAt;

  ConversionTask({
    required this.id,
    required this.inputPath,
    required this.outputPath,
    required this.format,
    required this.bitrate,
    this.startTime,
    this.endTime,
    this.progress = 0,
    this.status = ConversionStatus.queued,
    this.error,
    this.startedAt,
    this.completedAt,
  });

  // Create a copy with some updated fields
  ConversionTask copyWith({
    String? id,
    String? inputPath,
    String? outputPath,
    String? format,
    String? bitrate,
    Duration? startTime,
    Duration? endTime,
    int? progress,
    ConversionStatus? status,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ConversionTask(
      id: id ?? this.id,
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      format: format ?? this.format,
      bitrate: bitrate ?? this.bitrate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
