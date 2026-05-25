import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/conversion_service.dart';
import '../utils/format_options.dart';
import '../utils/app_logger.dart';

class AudioConverterScreen extends StatefulWidget {
  const AudioConverterScreen({super.key});

  @override
  State<AudioConverterScreen> createState() => _AudioConverterScreenState();
}

class _AudioConverterScreenState extends State<AudioConverterScreen> {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final ConversionService _conversionService = ConversionService();

  bool _isLoading = false;
  int _selectedFormatIndex = 0;
  int _selectedBitrateIndex = 0;
  String? _selectedAudioPath;
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
        type: FileType.audio,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _selectedFile = result.files.first;
        _selectedAudioPath = result.files.first.path;
      });
    } catch (e) {
      _showSnackBar('Failed to pick file: $e');
    }
  }

  Future<void> _handleConversion() async {
    if (_selectedAudioPath == null) {
      _showSnackBar('Please select an audio first');
      return;
    }

    final hasPermission = await _storageService.requestFullStoragePermission();
    if (!hasPermission) {
      _showSnackBar('Storage permission is required to save the converted file');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formatOpt = audioFormatOptions[_selectedFormatIndex];
      final bitrates = formatOpt['bitrateOptions'] as List<dynamic>;
      final selectedBitrate = bitrates[_selectedBitrateIndex]['value'] as String;

      await _conversionService.convertAudioOrVideo(
        _selectedAudioPath!,
        format: formatOpt['extension'] as String,
        type: 'audio',
        bitrate: selectedBitrate,
      );
      if (mounted) _showSnackBar('Conversion started...');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to convert: $e');
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
    final currentFormat = audioFormatOptions[_selectedFormatIndex];
    final bitrates = currentFormat['bitrateOptions'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Converter'),
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
                  'Convert Audio Format',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Select an audio file to convert to another format.'),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Output Format:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedFormatIndex,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: List.generate(
                            audioFormatOptions.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(audioFormatOptions[index]['name'] as String),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedFormatIndex = val;
                                _selectedBitrateIndex = 0; // Reset bitrate
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Quality (Bitrate):', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedBitrateIndex,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: List.generate(
                            bitrates.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text('${bitrates[index]['quality']} (${bitrates[index]['value']})'),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedBitrateIndex = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedAudioPath != null)
                  _buildSelectedAudioCard(_selectedAudioPath!, theme),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : (_selectedAudioPath == null ? _pickFile : _handleConversion),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_selectedAudioPath == null ? Icons.file_upload : Icons.play_arrow),
                  label: Text(_selectedAudioPath == null ? 'Select Audio' : 'Convert Audio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedAudioCard(String filePath, ThemeData theme) {
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
              child: const Icon(Icons.audio_file, size: 40),
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
                    'Audio File • ${sizeInMb.toStringAsFixed(2)} MB',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectedAudioPath = null;
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
