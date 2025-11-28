import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoTrimmer extends StatefulWidget {
  final String videoPath;
  final Duration initialStart;
  final Duration initialEnd;
  final ValueChanged<MapEntry<Duration, Duration>>? onTrim;

  const VideoTrimmer({
    super.key,
    required this.videoPath,
    required this.initialStart,
    required this.initialEnd,
    this.onTrim,
  });

  @override
  State<VideoTrimmer> createState() => _VideoTrimmerState();
}

class _VideoTrimmerState extends State<VideoTrimmer> {
  late VideoPlayerController _controller;
  bool _loading = true;

  late Duration _start;
  late Duration _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));

    await _controller.initialize();
    await _controller.setLooping(false);

    final duration = _controller.value.duration;
    _start = _clamp(_start, Duration.zero, duration);
    _end = _clamp(_end, Duration.zero, duration);
    if (_end < _start) _end = _start;

    await _controller.seekTo(_start);

    // LISTENER penting agar playback tidak melewati _end
    _controller.addListener(() {
      final pos = _controller.value.position;
      if (_controller.value.isPlaying && pos >= _end) {
        _controller.pause();
        _controller.seekTo(_start);
        setState(() {});
      }
    });

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Duration _clamp(Duration d, Duration min, Duration max) {
    if (d < min) return min;
    if (d > max) return max;
    return d;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.seekTo(_start);
      await _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final duration = _controller.value.duration;

    return Column(
      children: [
        _buildVideoPlayer(),

        const SizedBox(height: 24),

        _buildTrimSlider(duration),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size?.width ?? 0,
                  height: _controller.value.size?.height ?? 0,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

            Positioned.fill(
              child: Center(
                child: IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: _togglePlay,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimSlider(Duration videoDuration) {
    final maxMs = videoDuration.inMilliseconds.toDouble();

    return StatefulBuilder(
      builder: (context, setLocal) {
        final safeStart = _start.inMilliseconds.clamp(0, maxMs).toDouble();
        final safeEnd = _end.inMilliseconds.clamp(0, maxMs).toDouble();

        return Column(
          children: [
            RangeSlider(
              min: 0,
              max: maxMs,
              values: RangeValues(safeStart, safeEnd),
              onChanged: (v) {
                final s = Duration(milliseconds: v.start.toInt());
                final e = Duration(milliseconds: v.end.toInt());

                setLocal(() {
                  _start = _clamp(s, Duration.zero, videoDuration);
                  _end = _clamp(e, Duration.zero, videoDuration);
                  if (_end < _start) _end = _start;
                });
              },
              onChangeEnd: (v) async {
                final s = Duration(milliseconds: v.start.toInt());
                final e = Duration(milliseconds: v.end.toInt());

                _start = _clamp(s, Duration.zero, videoDuration);
                _end = _clamp(e, Duration.zero, videoDuration);
                if (_end < _start) _end = _start;

                setState(() {});

                await _controller.pause();
                await _controller.seekTo(_start);

                widget.onTrim?.call(MapEntry(_start, _end));
              },
            ),

            Text(
              '${_format(_start)} - ${_format(_end)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
