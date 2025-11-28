import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/conversion_service.dart';
import '../utils/format_options.dart';
import '../widgets/duration_picker_dialog.dart';
import '../widgets/format_quality_selector.dart';
import '../widgets/convert_button_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final ConversionService _conversionService = ConversionService();

  bool _isLoading = false;

  // Format options
  final List<Map<String, dynamic>> _formatOptions = audioFormatOptions;
  int _selectedFormatIndex = 0;
  String _selectedBitrate = '192k';

  // Duration selection
  Duration? _startTime;
  Duration? _endTime;
  bool _hasEndTime = false;
  String? _selectedVideoPath;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  // Consolidate all initialization
  Future<void> _initializeServices() async {
    try {
      await _notificationService.initialize();
      _notificationService.setOnNotificationTapped(_handleNotificationTap);
    } catch (e) {
      _showSnackBar('Gagal menginisialisasi: $e');
    }
  }

  // Single handler for notification taps
  void _handleNotificationTap(String? filePath) {
    if (filePath != null) {
      _storageService.openFileDirectory(filePath).catchError((e) {
        _showSnackBar('Gagal membuka direktori: $e');
      });
    }
  }

  Future<void> _showDurationPicker() async {
    if (_selectedVideoPath == null) {
      _showSnackBar('Pilih video terlebih dahulu');
      return;
    }

    final result = await DurationPickerDialog.show(
      context,
      videoPath: _selectedVideoPath!,
      initialStart: _startTime,
      initialEnd: _hasEndTime ? _endTime : null,
      maxDuration: const Duration(hours: 23, minutes: 59, seconds: 59),
    );

    setState(() {
      _startTime = result.key;
      _endTime = result.value ?? (result.key + const Duration(seconds: 30));
      _hasEndTime = result.value != null;
    });
  }

  void _clearDurationSelection() {
    setState(() {
      _startTime = null;
      _endTime = null;
      _hasEndTime = false;
      _selectedVideoPath = null;
    });
  }

  // Clean conversion handler - ConversionService handles everything
  Future<void> _handleConversion() async {
    if (!_validateConversion()) return;

    setState(() => _isLoading = true);

    try {
      await _conversionService.convertFile(
        _selectedVideoPath!,
        format: _formatOptions[_selectedFormatIndex]['extension'] as String,
        bitrate: _selectedBitrate,
        start: _startTime,
        end: _hasEndTime ? _endTime : null,
        onProgress: _handleProgress,
      );

      // ConversionService already shows notification
      // Just show local feedback
      if (mounted) {
        _showSnackBar('Konversi berhasil!');
      }
    } catch (e) {
      // ConversionService already shows error notification
      // Just show local feedback
      if (mounted) {
        _showSnackBar('Gagal mengkonversi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Validation logic extracted
  bool _validateConversion() {
    if (_selectedVideoPath == null) {
      _showSnackBar('Pilih video terlebih dahulu');
      return false;
    }

    if (_startTime == null) {
      _showSnackBar('Atur durasi terlebih dahulu');
      return false;
    }

    return true;
  }

  // Progress handler
  void _handleProgress(dynamic task) {
    if (mounted) {
      setState(() {
        // Update UI based on task progress
      });
    }
  }

  Future<void> _pickAndConvertFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      setState(() {
        _selectedVideoPath = file.path!;
      });

      await _showDurationPicker();
    } catch (e) {
      _showSnackBar('Gagal memilih file: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _notificationService.cancelAllNotifications();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(colorScheme),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'MP4 to MP3',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    return Container(
      decoration: _buildGradientDecoration(colorScheme),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildFormatSelector(),
              const SizedBox(height: 16),
              _buildConvertSection(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorScheme.primary.withValues(alpha: 0.1),
          colorScheme.primary.withValues(alpha: 0.05),
          colorScheme.surface,
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Convert Video to MP3',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a video file to convert to high-quality MP3 audio',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return FormatQualitySelector(
      formatOptions: _formatOptions,
      selectedFormatIndex: _selectedFormatIndex,
      selectedBitrate: _selectedBitrate,
      isLoading: _isLoading,
      onFormatChanged: _handleFormatChanged,
      onBitrateChanged: _handleBitrateChanged,
    );
  }

  void _handleFormatChanged(int? newIndex) {
    if (newIndex != null) {
      setState(() {
        _selectedFormatIndex = newIndex;
        _selectedBitrate =
            _formatOptions[newIndex]['bitrateOptions'][0]['value'];
      });
    }
  }

  void _handleBitrateChanged(String? newBitrate) {
    if (newBitrate != null) {
      setState(() {
        _selectedBitrate = newBitrate;
      });
    }
  }

  Widget _buildConvertSection() {
    return ConvertButtonSection(
      isLoading: _isLoading,
      onPickVideo: _pickAndConvertFiles,
      onShowDurationPicker: _showDurationPicker,
      onClearDuration: _clearDurationSelection,
      onConvert: _handleConversion,
      startTime: _startTime,
      endTime: _endTime,
      hasEndTime: _hasEndTime,
      videoPath: _selectedVideoPath,
    );
  }
}
