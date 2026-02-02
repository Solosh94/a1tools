// CSV Export Utility
//
// Provides easy CSV export functionality for lists and tables.
// Supports Windows file save dialog integration.

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration for CSV export
class CsvExportConfig {
  /// Column headers
  final List<String> headers;

  /// Function to extract row values from data items
  final List<String> Function(dynamic item) rowExtractor;

  /// Optional custom filename (without extension)
  final String? filename;

  /// Optional date format for timestamps
  final String dateFormat;

  /// Whether to include timestamp in filename
  final bool includeTimestamp;

  const CsvExportConfig({
    required this.headers,
    required this.rowExtractor,
    this.filename,
    this.dateFormat = 'yyyy-MM-dd_HH-mm',
    this.includeTimestamp = true,
  });
}

/// Result of a CSV export operation
class CsvExportResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int rowCount;

  const CsvExportResult({
    required this.success,
    this.filePath,
    this.error,
    this.rowCount = 0,
  });

  factory CsvExportResult.success(String filePath, int rowCount) {
    return CsvExportResult(
      success: true,
      filePath: filePath,
      rowCount: rowCount,
    );
  }

  factory CsvExportResult.failure(String error) {
    return CsvExportResult(
      success: false,
      error: error,
    );
  }

  factory CsvExportResult.cancelled() {
    return const CsvExportResult(
      success: false,
      error: 'Export cancelled',
    );
  }
}

/// CSV Exporter utility class
class CsvExporter {
  CsvExporter._();

  /// Export data to CSV and save to file
  ///
  /// Returns [CsvExportResult] with success status and file path
  static Future<CsvExportResult> export<T>({
    required List<T> data,
    required CsvExportConfig config,
    BuildContext? context,
  }) async {
    if (data.isEmpty) {
      return CsvExportResult.failure('No data to export');
    }

    try {
      // Generate CSV content
      final csv = _generateCsv(data, config);

      // Generate filename
      final filename = _generateFilename(config);

      // Get save path
      final savePath = await _getSavePath(filename, context);
      if (savePath == null) {
        return CsvExportResult.cancelled();
      }

      // Write file
      final file = File(savePath);

      // Write with BOM for Excel compatibility
      final bom = utf8.encode('\uFEFF');
      final csvBytes = utf8.encode(csv);
      await file.writeAsBytes([...bom, ...csvBytes]);

      return CsvExportResult.success(savePath, data.length);
    } catch (e) {
      return CsvExportResult.failure('Export failed: $e');
    }
  }

  /// Export data to CSV and copy to clipboard
  static Future<CsvExportResult> copyToClipboard<T>({
    required List<T> data,
    required CsvExportConfig config,
  }) async {
    if (data.isEmpty) {
      return CsvExportResult.failure('No data to export');
    }

    try {
      final csv = _generateCsv(data, config);
      await Clipboard.setData(ClipboardData(text: csv));
      return CsvExportResult.success('clipboard', data.length);
    } catch (e) {
      return CsvExportResult.failure('Copy failed: $e');
    }
  }

  /// Generate CSV string from data
  static String _generateCsv<T>(List<T> data, CsvExportConfig config) {
    final buffer = StringBuffer();

    // Write headers
    buffer.writeln(_escapeCsvRow(config.headers));

    // Write data rows
    for (final item in data) {
      final row = config.rowExtractor(item);
      buffer.writeln(_escapeCsvRow(row));
    }

    return buffer.toString();
  }

  /// Escape a CSV row (handles commas, quotes, newlines)
  static String _escapeCsvRow(List<String> values) {
    return values.map(_escapeCsvValue).join(',');
  }

  /// Escape a single CSV value
  static String _escapeCsvValue(String value) {
    // If value contains comma, quote, or newline, wrap in quotes
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      // Escape existing quotes by doubling them
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Generate filename with optional timestamp
  static String _generateFilename(CsvExportConfig config) {
    final base = config.filename ?? 'export';

    if (config.includeTimestamp) {
      final now = DateTime.now();
      final timestamp = '${now.year}-${_pad(now.month)}-${_pad(now.day)}_${_pad(now.hour)}-${_pad(now.minute)}';
      return '${base}_$timestamp.csv';
    }

    return '$base.csv';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// Get save path (uses Downloads folder on Windows)
  static Future<String?> _getSavePath(String filename, BuildContext? context) async {
    try {
      // Default to Downloads folder
      String downloadsPath;

      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        downloadsPath = '$userProfile\\Downloads';
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME'];
        downloadsPath = '$home/Downloads';
      } else {
        // Mobile - use app documents directory
        downloadsPath = Directory.systemTemp.path;
      }

      // Ensure directory exists
      final dir = Directory(downloadsPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      return '$downloadsPath${Platform.pathSeparator}$filename';
    } catch (e) {
      debugPrint('[CsvExporter] Error getting save path: $e');
      return null;
    }
  }
}

/// Extension to show export button easily
extension CsvExportButton on Widget {
  /// Wraps this widget with an export button
  Widget withExportButton<T>({
    required List<T> data,
    required CsvExportConfig config,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Expanded(child: this),
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Export to CSV',
          onPressed: () => _handleExport(context, data, config),
        ),
      ],
    );
  }
}

Future<void> _handleExport<T>(
  BuildContext context,
  List<T> data,
  CsvExportConfig config,
) async {
  final result = await CsvExporter.export(
    data: data,
    config: config,
    context: context,
  );

  if (!context.mounted) return;

  if (result.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Exported ${result.rowCount} rows to ${result.filePath}'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Open Folder',
          textColor: Colors.white,
          onPressed: () {
            if (result.filePath != null) {
              final dir = File(result.filePath!).parent.path;
              if (Platform.isWindows) {
                Process.run('explorer', [dir]);
              } else if (Platform.isMacOS) {
                Process.run('open', [dir]);
              } else if (Platform.isLinux) {
                Process.run('xdg-open', [dir]);
              }
            }
          },
        ),
      ),
    );
  } else if (result.error != 'Export cancelled') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(result.error ?? 'Export failed'),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
