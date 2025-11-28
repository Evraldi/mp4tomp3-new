import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:mp4tomp3/widgets/video_trimmer.dart';

class DurationPickerDialog extends StatefulWidget {
  final String? videoPath;
  final Duration? initialStart;
  final Duration? initialEnd;

  const DurationPickerDialog({
    super.key,
    this.videoPath,
    this.initialStart,
    this.initialEnd,
  });

  static Future<MapEntry<Duration, Duration?>> show(
    BuildContext context, {
    required String videoPath,
    Duration? initialStart,
    Duration? initialEnd,
    Duration? maxDuration,
  }) async {
    final result = await showDialog<MapEntry<Duration, Duration?>>(
      context: context,
      builder: (context) => DurationPickerDialog(
        videoPath: videoPath,
        initialStart: initialStart,
        initialEnd: initialEnd,
      ),
    );
    return result ?? MapEntry(Duration.zero, null);
  }

  @override
  DurationPickerDialogState createState() => DurationPickerDialogState();
}

class DurationPickerDialogState extends State<DurationPickerDialog> {
  late Duration _startTime;
  late Duration _endTime;
  bool _hasEndTime = false;

  @override
  void initState() {
    super.initState();

    _startTime = widget.initialStart ?? Duration.zero;
    _endTime = widget.initialEnd ?? _startTime + const Duration(seconds: 30);
    _hasEndTime = widget.initialEnd != null;
  }

  @override
  Widget build(BuildContext context) {
    final safeStart = _startTime;
    final safeEnd = _hasEndTime
        ? _endTime
        : _startTime + const Duration(seconds: 30);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height *
              0.43, // Reduced from 0.8 to 0.5 (80% to 50%)
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        path.basename(widget.videoPath ?? ''),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: VideoTrimmer(
                      videoPath: widget.videoPath!,
                      initialStart: safeStart,
                      initialEnd: safeEnd,
                      onTrim: (value) {
                        setState(() {
                          _startTime = value.key;
                          _endTime =
                              value.value ??
                              _startTime + const Duration(seconds: 30);
                          _hasEndTime = value.value != null;
                        });
                      },
                    ),
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'BATAL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          MapEntry(_startTime, _hasEndTime ? _endTime : null),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'SIMPAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
