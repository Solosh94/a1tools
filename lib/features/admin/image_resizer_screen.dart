// Image Resizer Screen
//
// Allows compressing images that exceed a specified file size threshold.
// Only modifies images that are larger than the set limit.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class ImageResizerScreen extends StatefulWidget {
 const ImageResizerScreen({super.key});

 @override
 State<ImageResizerScreen> createState() => _ImageResizerScreenState();
}

class _ImageResizerScreenState extends State<ImageResizerScreen> {
 String _inputFolder = '';
 String _outputFolder = '';
 double _maxFileSizeMB = 10.0; // Default 10 MB
 int _jpegQuality = 85; // JPEG quality for compression
 int _maxDimension = 4096; // Max width/height
 bool _overwriteOriginals = false;

 List<_ImageFileInfo> _imageFiles = [];
 List<_ImageFileInfo> _filesToProcess = [];

 bool _isProcessing = false;
 double _processProgress = 0.0;
 String _processStatus = '';
 int _processedCount = 0;
 int _skippedCount = 0;

 Future<void> _browseInputFolder() async {
 final result = await FilePicker.platform.getDirectoryPath(
 dialogTitle: 'Select Input Folder',
 );
 if (result != null) {
 setState(() {
 _inputFolder = result;
 // Auto-set output folder if not set
 if (_outputFolder.isEmpty) {
 _outputFolder = path.join(result, 'resized');
 }
 });
 await _scanFolder();
 }
 }

 Future<void> _browseOutputFolder() async {
 final result = await FilePicker.platform.getDirectoryPath(
 dialogTitle: 'Select Output Folder',
 );
 if (result != null) {
 setState(() {
 _outputFolder = result;
 });
 }
 }

 Future<void> _scanFolder() async {
 if (_inputFolder.isEmpty) return;

 setState(() {
 _imageFiles = [];
 _filesToProcess = [];
 _processStatus = 'Scanning folder...';
 });

 final dir = Directory(_inputFolder);
 if (!await dir.exists()) {
 setState(() => _processStatus = 'Folder does not exist');
 return;
 }

 final files = <_ImageFileInfo>[];
 final maxBytes = (_maxFileSizeMB * 1024 * 1024).round();

 await for (final entity in dir.list(recursive: true)) {
 if (entity is File) {
 final ext = path.extension(entity.path).toLowerCase();
 if (['.png', '.jpg', '.jpeg', '.webp', '.bmp'].contains(ext)) {
 final stat = await entity.stat();
 final fileInfo = _ImageFileInfo(
 path: entity.path,
 fileName: path.basename(entity.path),
 sizeBytes: stat.size,
 exceedsLimit: stat.size > maxBytes,
 );
 files.add(fileInfo);
 }
 }
 }

 // Sort by size descending
 files.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

 final toProcess = files.where((f) => f.exceedsLimit).toList();

 setState(() {
 _imageFiles = files;
 _filesToProcess = toProcess;
 _processStatus = 'Found ${files.length} images, ${toProcess.length} exceed ${_maxFileSizeMB.toStringAsFixed(1)} MB';
 });
 }

 String _formatFileSize(int bytes) {
 if (bytes < 1024) return '$bytes B';
 if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
 return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
 }

 Future<void> _processImages() async {
 if (_filesToProcess.isEmpty) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('No images exceed the size limit'),
 backgroundColor: Colors.orange,
 ),
 );
 return;
 }

 if (_outputFolder.isEmpty && !_overwriteOriginals) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Please select an output folder'),
 backgroundColor: Colors.orange,
 ),
 );
 return;
 }

 setState(() {
 _isProcessing = true;
 _processProgress = 0.0;
 _processedCount = 0;
 _skippedCount = 0;
 _processStatus = 'Starting...';
 });

 // Create output folder if needed
 if (!_overwriteOriginals) {
 await Directory(_outputFolder).create(recursive: true);
 }

 final maxBytes = (_maxFileSizeMB * 1024 * 1024).round();

 for (int i = 0; i < _filesToProcess.length; i++) {
 final fileInfo = _filesToProcess[i];

 setState(() {
 _processStatus = 'Processing: ${fileInfo.fileName}';
 _processProgress = i / _filesToProcess.length;
 });

 try {
 final inputFile = File(fileInfo.path);
 final bytes = await inputFile.readAsBytes();
 var image = img.decodeImage(bytes);

 if (image == null) {
 _skippedCount++;
 continue;
 }

 // Resize if dimensions are too large
 if (image.width > _maxDimension || image.height > _maxDimension) {
 if (image.width > image.height) {
 image = img.copyResize(image, width: _maxDimension);
 } else {
 image = img.copyResize(image, height: _maxDimension);
 }
 }

 // Compress with varying quality until under limit
 Uint8List outputBytes;
 int currentQuality = _jpegQuality;

 do {
 outputBytes = Uint8List.fromList(img.encodeJpg(image, quality: currentQuality));
 currentQuality -= 5;
 } while (outputBytes.length > maxBytes && currentQuality > 10);

 // Determine output path
 String outputPath;
 if (_overwriteOriginals) {
 // Change extension to .jpg if not already
 final baseName = path.basenameWithoutExtension(fileInfo.path);
 final dirName = path.dirname(fileInfo.path);
 outputPath = path.join(dirName, '$baseName.jpg');
 } else {
 // Preserve folder structure in output
 final relativePath = path.relative(fileInfo.path, from: _inputFolder);
 final relativeDir = path.dirname(relativePath);
 final baseName = path.basenameWithoutExtension(fileInfo.fileName);

 final outputDir = path.join(_outputFolder, relativeDir);
 await Directory(outputDir).create(recursive: true);
 outputPath = path.join(outputDir, '$baseName.jpg');
 }

 await File(outputPath).writeAsBytes(outputBytes);

 // Update file info with new size
 fileInfo.newSizeBytes = outputBytes.length;
 fileInfo.processed = true;

 _processedCount++;
 } catch (e) {
 debugPrint('Error processing ${fileInfo.fileName}: $e');
 _skippedCount++;
 }

 setState(() {
 _processProgress = (i + 1) / _filesToProcess.length;
 });
 }

 setState(() {
 _isProcessing = false;
 _processStatus = 'Completed: $_processedCount processed, $_skippedCount skipped';
 });

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Processed $_processedCount images, skipped $_skippedCount'),
 backgroundColor: Colors.green,
 ),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 return Scaffold(
 appBar: AppBar(
 title: const Text('Image Resizer'),
 actions: [
 IconButton(
 icon: const Icon(Icons.help_outline),
 onPressed: _showHelp,
 ),
 ],
 ),
 body: Row(
 children: [
 // Settings Panel (left)
 SizedBox(
 width: 400,
 child: _buildSettingsPanel(),
 ),
 const VerticalDivider(width: 1),
 // Files Panel (right)
 Expanded(
 child: _buildFilesPanel(),
 ),
 ],
 ),
 );
 }

 Widget _buildSettingsPanel() {
 return SingleChildScrollView(
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Input Folder
 const Text(
 'Folders',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 8),
 _buildFolderRow('Input Folder', _inputFolder, _browseInputFolder),
 const SizedBox(height: 8),
 _buildFolderRow('Output Folder', _outputFolder, _browseOutputFolder),

 // Overwrite option
 CheckboxListTile(
 title: const Text('Overwrite original files'),
 subtitle: const Text('Warning: This will replace the original images'),
 value: _overwriteOriginals,
 onChanged: (v) => setState(() => _overwriteOriginals = v ?? false),
 controlAffinity: ListTileControlAffinity.leading,
 contentPadding: EdgeInsets.zero,
 ),

 const Divider(height: 32),

 // Size Settings
 const Text(
 'Size Settings',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 16),

 // Max file size
 Row(
 children: [
 const SizedBox(width: 120, child: Text('Max File Size:')),
 Expanded(
 child: Slider(
 value: _maxFileSizeMB,
 min: 0.5,
 max: 50,
 divisions: 99,
 label: '${_maxFileSizeMB.toStringAsFixed(1)} MB',
 onChanged: (v) => setState(() => _maxFileSizeMB = v),
 onChangeEnd: (_) => _scanFolder(),
 ),
 ),
 SizedBox(
 width: 60,
 child: Text('${_maxFileSizeMB.toStringAsFixed(1)} MB'),
 ),
 ],
 ),

 // JPEG Quality
 Row(
 children: [
 const SizedBox(width: 120, child: Text('JPEG Quality:')),
 Expanded(
 child: Slider(
 value: _jpegQuality.toDouble(),
 min: 10,
 max: 100,
 divisions: 18,
 label: '$_jpegQuality%',
 onChanged: (v) => setState(() => _jpegQuality = v.round()),
 ),
 ),
 SizedBox(
 width: 60,
 child: Text('$_jpegQuality%'),
 ),
 ],
 ),

 // Max dimension
 Row(
 children: [
 const SizedBox(width: 120, child: Text('Max Dimension:')),
 Expanded(
 child: Slider(
 value: _maxDimension.toDouble(),
 min: 800,
 max: 8192,
 divisions: 37,
 label: '$_maxDimension px',
 onChanged: (v) => setState(() => _maxDimension = v.round()),
 ),
 ),
 SizedBox(
 width: 60,
 child: Text('$_maxDimension'),
 ),
 ],
 ),

 const Divider(height: 32),

 // Stats
 const Text(
 'Summary',
 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
 ),
 const SizedBox(height: 8),
 Card(
 child: Padding(
 padding: const EdgeInsets.all(12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 _buildStatRow('Total Images', '${_imageFiles.length}'),
 _buildStatRow(
 'Exceeds Limit',
 '${_filesToProcess.length}',
 color: _filesToProcess.isNotEmpty ? Colors.orange : Colors.green,
 ),
 _buildStatRow(
 'Within Limit',
 '${_imageFiles.length - _filesToProcess.length}',
 color: Colors.green,
 ),
 if (_filesToProcess.isNotEmpty) ...[
 const Divider(),
 _buildStatRow(
 'Total Size to Process',
 _formatFileSize(_filesToProcess.fold(0, (sum, f) => sum + f.sizeBytes)),
 ),
 ],
 ],
 ),
 ),
 ),

 const SizedBox(height: 24),

 // Process button
 if (_isProcessing) ...[
 LinearProgressIndicator(value: _processProgress),
 const SizedBox(height: 8),
 Text(_processStatus, textAlign: TextAlign.center),
 const SizedBox(height: 8),
 ],

 SizedBox(
 width: double.infinity,
 child: ElevatedButton.icon(
 onPressed: _isProcessing || _filesToProcess.isEmpty ? null : _processImages,
 icon: Icon(_isProcessing ? Icons.hourglass_top : Icons.compress),
 label: Text(_isProcessing
 ? 'Processing...'
 : _filesToProcess.isEmpty
 ? 'No Files to Process'
 : 'Process ${_filesToProcess.length} Images'),
 style: ElevatedButton.styleFrom(
 padding: const EdgeInsets.all(16),
 backgroundColor: _filesToProcess.isNotEmpty ? Colors.blue : Colors.grey,
 foregroundColor: Colors.white,
 ),
 ),
 ),

 if (_inputFolder.isNotEmpty) ...[
 const SizedBox(height: 8),
 SizedBox(
 width: double.infinity,
 child: OutlinedButton.icon(
 onPressed: _isProcessing ? null : _scanFolder,
 icon: const Icon(Icons.refresh),
 label: const Text('Rescan Folder'),
 ),
 ),
 ],
 ],
 ),
 );
 }

 Widget _buildFolderRow(String label, String value, VoidCallback onBrowse) {
 return Row(
 children: [
 SizedBox(
 width: 100,
 child: Text(label),
 ),
 Expanded(
 child: Text(
 value.isEmpty ? 'Not selected' : value,
 overflow: TextOverflow.ellipsis,
 style: TextStyle(
 color: value.isEmpty ? Colors.grey : null,
 fontSize: 12,
 ),
 ),
 ),
 const SizedBox(width: 8),
 ElevatedButton(
 onPressed: _isProcessing ? null : onBrowse,
 child: const Text('Browse'),
 ),
 ],
 );
 }

 Widget _buildStatRow(String label, String value, {Color? color}) {
 return Padding(
 padding: const EdgeInsets.symmetric(vertical: 4),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(label),
 Text(
 value,
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: color,
 ),
 ),
 ],
 ),
 );
 }

 Widget _buildFilesPanel() {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header
 Container(
 padding: const EdgeInsets.all(16),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text(
 'Images (${_imageFiles.length})',
 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
 ),
 if (_processStatus.isNotEmpty)
 Text(
 _processStatus,
 style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
 ),
 ],
 ),
 ),
 const Divider(height: 1),

 // Files list
 Expanded(
 child: _imageFiles.isEmpty
 ? Center(
 child: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
 const SizedBox(height: 16),
 Text(
 'Select an input folder to scan for images',
 style: TextStyle(color: Colors.grey.shade600),
 ),
 ],
 ),
 )
 : ListView.builder(
 itemCount: _imageFiles.length,
 itemBuilder: (context, index) {
 final file = _imageFiles[index];
 return _buildFileRow(file);
 },
 ),
 ),
 ],
 );
 }

 Widget _buildFileRow(_ImageFileInfo file) {
 final exceedsLimit = file.exceedsLimit;
 final processed = file.processed;

 Color statusColor;
 IconData statusIcon;
 String statusText;

 if (processed) {
 statusColor = Colors.green;
 statusIcon = Icons.check_circle;
 statusText = 'Processed: ${_formatFileSize(file.newSizeBytes ?? 0)}';
 } else if (exceedsLimit) {
 statusColor = Colors.orange;
 statusIcon = Icons.warning;
 statusText = 'Exceeds limit';
 } else {
 statusColor = Colors.grey;
 statusIcon = Icons.check;
 statusText = 'OK';
 }

 return ListTile(
 leading: Icon(statusIcon, color: statusColor),
 title: Text(
 file.fileName,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(fontSize: 13),
 ),
 subtitle: Text(
 path.dirname(file.path).replaceFirst(_inputFolder, '.'),
 overflow: TextOverflow.ellipsis,
 style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
 ),
 trailing: Column(
 mainAxisAlignment: MainAxisAlignment.center,
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 _formatFileSize(file.sizeBytes),
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: exceedsLimit ? Colors.orange : Colors.grey.shade700,
 ),
 ),
 Text(
 statusText,
 style: TextStyle(fontSize: 11, color: statusColor),
 ),
 ],
 ),
 );
 }

 void _showHelp() {
 showDialog(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Image Resizer Help'),
 content: const SingleChildScrollView(
 child: Text(
 'Image Resizer compresses images that exceed a specified file size.\n\n'
 'How to use:\n'
 '1. Select an input folder containing images\n'
 '2. Set the maximum file size threshold (e.g., 10 MB)\n'
 '3. Adjust JPEG quality and max dimensions as needed\n'
 '4. Choose an output folder (or overwrite originals)\n'
 '5. Click "Process" to compress only the images that exceed the limit\n\n'
 'Features:\n'
 '•• Only processes images that exceed the size limit\n'
 '•• Preserves folder structure in output\n'
 '•• Automatically adjusts quality to meet size target\n'
 '•• Converts all output to JPEG for best compression\n'
 '•• Shows before/after file sizes',
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('OK'),
 ),
 ],
 ),
 );
 }
}

class _ImageFileInfo {
 final String path;
 final String fileName;
 final int sizeBytes;
 final bool exceedsLimit;
 int? newSizeBytes;
 bool processed = false;

 _ImageFileInfo({
 required this.path,
 required this.fileName,
 required this.sizeBytes,
 required this.exceedsLimit,
 });
}
