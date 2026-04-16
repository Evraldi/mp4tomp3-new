import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../services/ffmpeg_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/conversion_service.dart';
import '../utils/format_options.dart';
import '../utils/app_logger.dart';

class VideoCompressorScreen extends StatefulWidget {
  const VideoCompressorScreen({super.key});

  @override
  State<VideoCompressorScreen> createState() => _VideoCompressorScreenState();
}

class _VideoCompressorScreenState extends State<VideoCompressorScreen> {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final ConversionService _conversionService = ConversionService();

  bool _isLoading = false;
  int _selectedOptionIndex = 0;
  String? _selectedVideoPath;
  String? _thumbnailPath;
  bool _isGeneratingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _notificationService.initialize();
      _notificationService.setOnNotificationTapped(_handleNotificationTap);
    } catch (e) {
      _showSnackBar('Gagal menginisialisasi: $e');
    }
  }

  void _handleNotificationTap(String? filePath) {
    AppLogger.info('Notification tapped, action disabled.');
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _selectedVideoPath = result.files.first.path;
        _isGeneratingThumbnail = true;
      });

      // Generate thumbnail
      final tempDir = await getTemporaryDirectory();
      final thumbPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final success = await FFMpegService.generateThumbnail(_selectedVideoPath!, thumbPath);
      
      if (mounted) {
        setState(() {
          if (success) _thumbnailPath = thumbPath;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      _showSnackBar('Gagal memilih file: $e');
    }
  }

  Future<void> _handleCompression() async {
    if (_selectedVideoPath == null) {
      _showSnackBar('Pilih video terlebih dahulu');
      return;
    }

    // Pastikan izin penyimpanan sudah diberikan
    final hasPermission = await _storageService.requestFullStoragePermission();
    if (!hasPermission) {
      _showSnackBar('Izin penyimpanan diperlukan untuk menyimpan hasil konversi');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final option = videoCompressionOptions[_selectedOptionIndex];
      await _conversionService.compressVideo(
        _selectedVideoPath!,
        resolution: option['resolution'] as String,
        crf: option['crf'] as String,
      );
      if (mounted) _showSnackBar('Kompresi dimulai...');
    } catch (e) {
      if (mounted) _showSnackBar('Gagal mengkompresi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Compressor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.1),
              colorScheme.primary.withOpacity(0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Compress Video',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Select a video file to compress and reduce file size.'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Compression Quality:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: _selectedOptionIndex,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: List.generate(
                            videoCompressionOptions.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(videoCompressionOptions[index]['name'] as String),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOptionIndex = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedVideoPath != null)
                  _buildSelectedVideoCard(_selectedVideoPath!, theme),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : (_selectedVideoPath == null ? _pickFile : _handleCompression),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_selectedVideoPath == null ? Icons.file_upload : Icons.compress),
                  label: Text(_selectedVideoPath == null ? 'Select Video' : 'Compress Video'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedVideoCard(String filePath, ThemeData theme) {
    final fileName = filePath.split('/').last;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Thumbnail container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnailWidget(),
            ),
            const SizedBox(width: 12),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Video File',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // Clear button
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectedVideoPath = null;
                _thumbnailPath = null;
              }),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailWidget() {
    if (_isGeneratingThumbnail) {
      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    
    if (_thumbnailPath != null) {
      return Image.file(
        File(_thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.movie),
      );
    }
    
    return const Icon(Icons.movie);
  }
}
