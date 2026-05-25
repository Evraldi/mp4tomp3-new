import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'package:path/path.dart' as path;

class MyStudioScreen extends StatefulWidget {
  const MyStudioScreen({super.key});

  @override
  State<MyStudioScreen> createState() => _MyStudioScreenState();
}

class _MyStudioScreenState extends State<MyStudioScreen> {
  final StorageService _storageService = StorageService();
  List<File> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final hasPermission = await _storageService.requestFullStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required to view your files')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final files = await _storageService.getAllConvertedFiles();
      setState(() {
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openFile(File file) async {
    try {
      await _storageService.openFile(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  void _deleteFile(File file) async {
    try {
      await file.delete();
      _loadFiles(); // refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: $e')),
        );
      }
    }
  }

  IconData _getIconForFile(String ext) {
    ext = ext.toLowerCase();
    if (['mp3', 'm4a', 'wav', 'ogg'].contains(ext)) return Icons.audiotrack;
    if (['mp4', 'mkv', 'avi'].contains(ext)) return Icons.movie;
    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _getColorForFile(String ext) {
    ext = ext.toLowerCase();
    if (['mp3', 'm4a', 'wav', 'ogg'].contains(ext)) return Colors.blue;
    if (['mp4', 'mkv', 'avi'].contains(ext)) return Colors.orange;
    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) return Colors.pink;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: colorScheme.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No files found',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Converted files will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final fileName = path.basename(file.path);
                        final ext = path.extension(file.path).replaceAll('.', '');
                        final icon = _getIconForFile(ext);
                        final color = _getColorForFile(ext);
                        
                        String sizeStr = 'Unknown';
                        try {
                          final size = file.lengthSync();
                          sizeStr = '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
                        } catch (_) {}

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color),
                            ),
                            title: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${ext.toUpperCase()} File • $sizeStr'),
                            onTap: () => _openFile(file),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete File?'),
                                    content: Text('Are you sure you want to delete "$fileName"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteFile(file);
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
