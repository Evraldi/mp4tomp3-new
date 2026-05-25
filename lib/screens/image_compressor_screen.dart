import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/conversion_service.dart';
import '../utils/format_options.dart';
import '../utils/app_logger.dart';

class ImageCompressorScreen extends StatefulWidget {
  const ImageCompressorScreen({super.key});

  @override
  State<ImageCompressorScreen> createState() => _ImageCompressorScreenState();
}

class _ImageCompressorScreenState extends State<ImageCompressorScreen> {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final ConversionService _conversionService = ConversionService();

  bool _isLoading = false;
  int _selectedCompressionIndex = 0;
  String? _selectedImagePath;
  PlatformFile? _selectedFile;

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
      _showSnackBar('Failed to initialize: $e');
    }
  }

  void _handleNotificationTap(String? filePath) {
    AppLogger.info('Notification tapped, action disabled.');
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _selectedFile = result.files.first;
        _selectedImagePath = result.files.first.path;
      });
    } catch (e) {
      _showSnackBar('Failed to pick file: $e');
    }
  }

  Future<void> _handleCompression() async {
    if (_selectedImagePath == null) {
      _showSnackBar('Please select an image first');
      return;
    }

    final hasPermission = await _storageService.requestFullStoragePermission();
    if (!hasPermission) {
      _showSnackBar('Storage permission is required to save the compressed file');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final compressOpt = imageCompressionOptions[_selectedCompressionIndex];

      await _conversionService.compressImage(
        _selectedImagePath!,
        scale: compressOpt['scale'] as String,
        quality: compressOpt['quality'] as String,
      );
      if (mounted) _showSnackBar('Compression started...');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to compress: $e');
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
        title: const Text('Image Compressor'),
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
                  'Reduce Image Size & Quality',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Select an image to easily compress its size and reduce its quality/resolution.'),
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
                          value: _selectedCompressionIndex,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: List.generate(
                            imageCompressionOptions.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(imageCompressionOptions[index]['name'] as String),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCompressionIndex = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedImagePath != null)
                  _buildSelectedImageCard(_selectedImagePath!, theme),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : (_selectedImagePath == null ? _pickFile : _handleCompression),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_selectedImagePath == null ? Icons.file_upload : Icons.compress),
                  label: Text(_selectedImagePath == null ? 'Select Image' : 'Compress Image'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImageCard(String filePath, ThemeData theme) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final sizeInBytes = _selectedFile?.size ?? 0;
    final sizeInMb = sizeInBytes / (1024 * 1024);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 40),
              ),
            ),
            const SizedBox(width: 12),
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
                    'Image File • ${sizeInMb.toStringAsFixed(2)} MB',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectedImagePath = null;
                _selectedFile = null;
              }),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}
