import 'package:flutter/material.dart';

class FormatQualitySelector extends StatelessWidget {
  final List<Map<String, dynamic>> formatOptions;
  final int selectedFormatIndex;
  final String selectedBitrate;
  final bool isLoading;
  final ValueChanged<int?> onFormatChanged;
  final ValueChanged<String?> onBitrateChanged;

  const FormatQualitySelector({
    super.key,
    required this.formatOptions,
    required this.selectedFormatIndex,
    required this.selectedBitrate,
    required this.isLoading,
    required this.onFormatChanged,
    required this.onBitrateChanged,
  });

  Map<String, dynamic> get _selectedFormat =>
      formatOptions[selectedFormatIndex];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Format Selector
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.audio_file_rounded, size: 20),
                const SizedBox(width: 12),
                Text('Format: ', style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedFormatIndex,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    elevation: 16,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: isLoading
                        ? null
                        : (value) => onFormatChanged(value),
                    items: List<DropdownMenuItem<int>>.generate(
                      formatOptions.length,
                      (index) => DropdownMenuItem<int>(
                        value: index,
                        child: Text(formatOptions[index]['name']),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Quality Selector
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.high_quality_rounded, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Quality: ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedBitrate,
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    elevation: 16,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    onChanged: isLoading
                        ? null
                        : (value) => onBitrateChanged(value),
                    items: (_selectedFormat['bitrateOptions'] as List)
                        .map<DropdownMenuItem<String>>((option) {
                          return DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(
                              '${option['quality']} (${option['value']})',
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
