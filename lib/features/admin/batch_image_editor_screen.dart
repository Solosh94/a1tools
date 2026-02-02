// Batch Image Editor Screen
//
// Allows bulk image processing with text overlays, backgrounds, and watermarks.
// Supports multiple batches with different phone numbers/suffixes.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

/// A batch configuration with phone number and suffix
class BatchConfig {
  String phoneNumber;
  String suffix;

  BatchConfig({required this.phoneNumber, required this.suffix});

  Map<String, dynamic> toJson() => {
    'phone_number': phoneNumber,
    'suffix': suffix,
  };

  factory BatchConfig.fromJson(Map<String, dynamic> json) => BatchConfig(
    phoneNumber: json['phone_number'] ?? '',
    suffix: json['suffix'] ?? '',
  );
}

/// All settings for the image editor
class ImageEditorSettings {
  String inputFolder;
  String outputFolder;
  String fontPath;
  int fontSize;
  Color textColor;
  Color bgColor;
  int xStart;
  int yStart;
  int width;
  int height;
  int textX;
  int textY;
  int letterSpacing;
  int bgRotation;
  int bgTransparency;
  int textRotation;
  int textTransparency;
  String watermarkPath;
  int watermarkSize;
  int watermarkX;
  int watermarkY;
  int watermarkRotation;
  int watermarkTransparency;
  bool disableBackground;
  bool disableFont;
  bool disableWatermark;
  String outputFormat;
  List<BatchConfig> batches;

  ImageEditorSettings({
    this.inputFolder = '',
    this.outputFolder = '',
    this.fontPath = '',
    this.fontSize = 32,
    this.textColor = Colors.white,
    this.bgColor = const Color(0xFF721522),
    this.xStart = 350,
    this.yStart = 30,
    this.width = 300,
    this.height = 40,
    this.textX = 370,
    this.textY = 30,
    this.letterSpacing = 0,
    this.bgRotation = 0,
    this.bgTransparency = 255,
    this.textRotation = 0,
    this.textTransparency = 255,
    this.watermarkPath = '',
    this.watermarkSize = 100,
    this.watermarkX = 0,
    this.watermarkY = 0,
    this.watermarkRotation = 0,
    this.watermarkTransparency = 128,
    this.disableBackground = false,
    this.disableFont = false,
    this.disableWatermark = false,
    this.outputFormat = 'original',
    List<BatchConfig>? batches,
  }) : batches = batches ?? [];

  Map<String, dynamic> toJson() => {
    'input_folder': inputFolder,
    'output_folder': outputFolder,
    'font_path': fontPath,
    'font_size': fontSize,
    'text_color': '#${textColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    'bg_color': '#${bgColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    'x_start': xStart,
    'y_start': yStart,
    'width': width,
    'height': height,
    'text_x': textX,
    'text_y': textY,
    'letter_spacing': letterSpacing,
    'bg_rotation': bgRotation,
    'bg_transparency': bgTransparency,
    'text_rotation': textRotation,
    'text_transparency': textTransparency,
    'watermark_path': watermarkPath,
    'watermark_size': watermarkSize,
    'watermark_x': watermarkX,
    'watermark_y': watermarkY,
    'watermark_rotation': watermarkRotation,
    'watermark_transparency': watermarkTransparency,
    'disable_background': disableBackground,
    'disable_font': disableFont,
    'disable_watermark': disableWatermark,
    'output_format': outputFormat,
    'batches': batches.map((b) => b.toJson()).toList(),
  };

  factory ImageEditorSettings.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return Colors.white;
      hex = hex.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    }

    return ImageEditorSettings(
      inputFolder: json['input_folder'] ?? '',
      outputFolder: json['output_folder'] ?? '',
      fontPath: json['font_path'] ?? '',
      fontSize: json['font_size'] ?? 32,
      textColor: parseColor(json['text_color']),
      bgColor: parseColor(json['bg_color']),
      xStart: json['x_start'] ?? 350,
      yStart: json['y_start'] ?? 30,
      width: json['width'] ?? 300,
      height: json['height'] ?? 40,
      textX: json['text_x'] ?? 370,
      textY: json['text_y'] ?? 30,
      letterSpacing: json['letter_spacing'] ?? 0,
      bgRotation: json['bg_rotation'] ?? 0,
      bgTransparency: json['bg_transparency'] ?? 255,
      textRotation: json['text_rotation'] ?? 0,
      textTransparency: json['text_transparency'] ?? 255,
      watermarkPath: json['watermark_path'] ?? '',
      watermarkSize: json['watermark_size'] ?? 100,
      watermarkX: json['watermark_x'] ?? 0,
      watermarkY: json['watermark_y'] ?? 0,
      watermarkRotation: json['watermark_rotation'] ?? 0,
      watermarkTransparency: json['watermark_transparency'] ?? 128,
      disableBackground: json['disable_background'] ?? false,
      disableFont: json['disable_font'] ?? false,
      disableWatermark: json['disable_watermark'] ?? false,
      outputFormat: json['output_format'] ?? 'original',
      batches: (json['batches'] as List?)?.map((b) => BatchConfig.fromJson(b)).toList() ?? [],
    );
  }
}

class BatchImageEditorScreen extends StatefulWidget {
  const BatchImageEditorScreen({super.key});

  @override
  State<BatchImageEditorScreen> createState() => _BatchImageEditorScreenState();
}

class _BatchImageEditorScreenState extends State<BatchImageEditorScreen> {
  ImageEditorSettings _settings = ImageEditorSettings();
  int _selectedBatchIndex = 0;
  List<String> _imageFiles = [];
  int _previewImageIndex = 0;
  Uint8List? _previewBytes;
  Uint8List? _originalImageBytes; // For color picking from original image
  bool _isProcessing = false;
  double _processProgress = 0.0;
  String _processStatus = '';

  // Eyedropper mode
  bool _eyedropperMode = false;
  String _eyedropperTarget = ''; // 'text' or 'bg'

  // Font data cache
  img.BitmapFont? _customFont;

  @override
  void initState() {
    super.initState();
    _loadDefaultSettings();
  }

  Future<void> _loadDefaultSettings() async {
    // Try to load the default A1 Chimney settings
    final settingsPath = path.join(
      Directory.current.path,
      'bulk_image_maker',
      'settings',
      'A1 Chimney.json',
    );
    final file = File(settingsPath);
    if (await file.exists()) {
      try {
        final json = jsonDecode(await file.readAsString());
        setState(() {
          _settings = ImageEditorSettings.fromJson(json);
        });
      } catch (e) {
        debugPrint('Failed to load default settings: $e');
      }
    }
  }

  Future<void> _browseInputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Input Folder',
    );
    if (result != null) {
      setState(() {
        _settings.inputFolder = result;
      });
      await _loadImageFiles();
    }
  }

  Future<void> _browseOutputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Output Folder',
    );
    if (result != null) {
      setState(() {
        _settings.outputFolder = result;
      });
    }
  }

  Future<void> _browseFontFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Font File',
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _settings.fontPath = result.files.single.path!;
        _customFont = null; // Reset cached font
        _loadedFontFamily = null; // Reset loaded font family
      });
      await _updatePreview();
    }
  }

  Future<void> _loadImageFiles() async {
    if (_settings.inputFolder.isEmpty) return;

    final dir = Directory(_settings.inputFolder);
    if (!await dir.exists()) return;

    final files = await dir.list().where((f) {
      if (f is! File) return false;
      final ext = path.extension(f.path).toLowerCase();
      return ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif'].contains(ext);
    }).map((f) => f.path).toList();

    setState(() {
      _imageFiles = files;
      _previewImageIndex = 0;
    });

    if (_imageFiles.isNotEmpty) {
      await _updatePreview();
    }
  }

  Future<void> _updatePreview() async {
    if (_imageFiles.isEmpty || _settings.batches.isEmpty) {
      setState(() {
        _previewBytes = null;
        _originalImageBytes = null;
      });
      return;
    }

    final imagePath = _imageFiles[_previewImageIndex];
    final batch = _settings.batches[_selectedBatchIndex];

    try {
      // Load original image for color picking
      final file = File(imagePath);
      if (await file.exists()) {
        _originalImageBytes = await file.readAsBytes();
      }

      final bytes = await _processImage(imagePath, batch.phoneNumber);
      setState(() => _previewBytes = bytes);
    } catch (e) {
      debugPrint('Preview error: $e');
    }
  }

  /// Rotate an image by angle (in degrees)
  img.Image _rotateImage(img.Image src, int angleDegrees) {
    if (angleDegrees == 0) return src;
    return img.copyRotate(src, angle: angleDegrees.toDouble());
  }

  // Cached custom font family name
  String? _loadedFontFamily;

  /// Load custom font from file using FontLoader
  Future<String> _getCustomFontFamily() async {
    if (_settings.fontPath.isEmpty) return 'Roboto';

    // If already loaded this font, return cached name
    if (_loadedFontFamily != null && _customFont != null) {
      return _loadedFontFamily!;
    }

    try {
      final fontFile = File(_settings.fontPath);
      if (!await fontFile.exists()) return 'Roboto';

      final fontData = await fontFile.readAsBytes();

      // Generate a unique font family name based on the file path
      final fontName = 'CustomFont_${path.basenameWithoutExtension(_settings.fontPath)}';

      // Load the font dynamically
      final loader = FontLoader(fontName);
      loader.addFont(Future.value(ByteData.sublistView(fontData)));
      await loader.load();

      _loadedFontFamily = fontName;
      return fontName;
    } catch (e) {
      debugPrint('Failed to load custom font: $e');
      return 'Roboto';
    }
  }

  /// Render text overlay using Flutter canvas (supports TTF fonts)
  Future<Uint8List?> _renderTextOverlay(String text, int imageWidth, int imageHeight) async {
    try {
      // Load custom font if specified
      final fontFamily = await _getCustomFontFamily();

      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Create text style with custom font
      final textStyle = TextStyle(
        fontFamily: fontFamily,
        fontSize: _settings.fontSize.toDouble(),
        color: _settings.textColor.withValues(alpha: _settings.textTransparency / 255),
        letterSpacing: _settings.letterSpacing.toDouble(),
      );

      // Create text painter
      final textSpan = TextSpan(text: text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Save canvas state for rotation
      canvas.save();

      if (_settings.textRotation != 0) {
        // Translate to text position, rotate, then draw
        canvas.translate(
          _settings.textX.toDouble() + textPainter.width / 2,
          _settings.textY.toDouble() + textPainter.height / 2,
        );
        canvas.rotate(_settings.textRotation * math.pi / 180);
        canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
        textPainter.paint(canvas, Offset.zero);
      } else {
        textPainter.paint(
          canvas,
          Offset(_settings.textX.toDouble(), _settings.textY.toDouble()),
        );
      }

      canvas.restore();

      // Convert to image
      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(imageWidth, imageHeight);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to render text overlay: $e');
      return null;
    }
  }

  Future<Uint8List?> _processImage(String imagePath, String text) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // Draw background rectangle
    if (!_settings.disableBackground) {
      final bgColor = img.ColorRgba8(
        (_settings.bgColor.r * 255).round(),
        (_settings.bgColor.g * 255).round(),
        (_settings.bgColor.b * 255).round(),
        _settings.bgTransparency,
      );

      if (_settings.bgRotation != 0) {
        // Create a rotated background rectangle
        var bgImage = img.Image(width: _settings.width, height: _settings.height);
        img.fill(bgImage, color: bgColor);
        bgImage = _rotateImage(bgImage, _settings.bgRotation);

        // Composite onto main image
        img.compositeImage(
          image,
          bgImage,
          dstX: _settings.xStart,
          dstY: _settings.yStart,
        );
      } else {
        img.fillRect(
          image,
          x1: _settings.xStart,
          y1: _settings.yStart,
          x2: _settings.xStart + _settings.width,
          y2: _settings.yStart + _settings.height,
          color: bgColor,
        );
      }
    }

    // Draw text using Flutter canvas for proper font support
    if (!_settings.disableFont && text.isNotEmpty) {
      final textOverlay = await _renderTextOverlay(
        text,
        image.width,
        image.height,
      );

      if (textOverlay != null) {
        // Decode the text overlay and composite it
        final overlayImage = img.decodeImage(textOverlay);
        if (overlayImage != null) {
          img.compositeImage(
            image,
            overlayImage,
            dstX: 0,
            dstY: 0,
          );
        }
      }
    }

    // Draw watermark
    if (!_settings.disableWatermark && _settings.watermarkPath.isNotEmpty) {
      final wmFile = File(_settings.watermarkPath);
      if (await wmFile.exists()) {
        final wmBytes = await wmFile.readAsBytes();
        var watermark = img.decodeImage(wmBytes);
        if (watermark != null) {
          // Resize watermark
          final aspectRatio = watermark.height / watermark.width;
          watermark = img.copyResize(
            watermark,
            width: _settings.watermarkSize,
            height: (_settings.watermarkSize * aspectRatio).round(),
          );

          // Apply rotation if needed
          if (_settings.watermarkRotation != 0) {
            watermark = _rotateImage(watermark, _settings.watermarkRotation);
          }

          // Apply transparency
          for (int y = 0; y < watermark.height; y++) {
            for (int x = 0; x < watermark.width; x++) {
              final pixel = watermark.getPixel(x, y);
              final a = (pixel.a * _settings.watermarkTransparency / 255).round();
              watermark.setPixel(x, y, img.ColorRgba8(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), a));
            }
          }

          // Composite watermark onto image
          img.compositeImage(
            image,
            watermark,
            dstX: _settings.watermarkX,
            dstY: _settings.watermarkY,
          );
        }
      }
    }

    // Encode to PNG for preview
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<void> _addBatch() async {
    final phoneController = TextEditingController();
    final suffixController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '(888) 555-1234',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: suffixController,
              decoration: const InputDecoration(
                labelText: 'Suffix (e.g., VA, NY)',
                hintText: 'DFW',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && phoneController.text.isNotEmpty && suffixController.text.isNotEmpty) {
      setState(() {
        _settings.batches.add(BatchConfig(
          phoneNumber: phoneController.text,
          suffix: suffixController.text,
        ));
        _selectedBatchIndex = _settings.batches.length - 1;
      });
      await _updatePreview();
    }
  }

  Future<void> _deleteBatch(int index) async {
    if (_settings.batches.isEmpty) return;

    setState(() {
      _settings.batches.removeAt(index);
      if (_selectedBatchIndex >= _settings.batches.length) {
        _selectedBatchIndex = (_settings.batches.length - 1).clamp(0, _settings.batches.length - 1);
      }
    });
    await _updatePreview();
  }

  Future<void> _saveSettings() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Settings',
      fileName: 'image_editor_settings.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final file = File(result);
      await file.writeAsString(jsonEncode(_settings.toJson()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings saved to $result')),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Load Settings',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final json = jsonDecode(content);
        setState(() {
          _settings = ImageEditorSettings.fromJson(json);
          _selectedBatchIndex = 0;
        });
        await _loadImageFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Settings loaded from ${result.files.single.path}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load settings: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _processAllBatches() async {
    if (_settings.batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No batches to process'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images found in input folder'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_settings.outputFolder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an output folder'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processProgress = 0.0;
      _processStatus = 'Starting...';
    });

    final totalImages = _settings.batches.length * _imageFiles.length;
    int processedCount = 0;

    try {
      for (final batch in _settings.batches) {
        // Create batch output folder
        final batchOutputPath = path.join(_settings.outputFolder, batch.suffix.toUpperCase());
        await Directory(batchOutputPath).create(recursive: true);

        for (final imagePath in _imageFiles) {
          setState(() {
            _processStatus = 'Processing ${batch.suffix}: ${path.basename(imagePath)}';
          });

          final processedBytes = await _processImage(imagePath, batch.phoneNumber);
          if (processedBytes != null) {
            // Determine output format
            String ext = _settings.outputFormat;
            if (ext == 'original') {
              ext = path.extension(imagePath).replaceFirst('.', '');
            }

            final outputFileName = '${path.basenameWithoutExtension(imagePath)}-${batch.suffix.toLowerCase()}.$ext';
            final outputPath = path.join(batchOutputPath, outputFileName);

            // Re-encode to target format
            final image = img.decodeImage(processedBytes);
            if (image != null) {
              Uint8List outputBytes;
              switch (ext.toLowerCase()) {
                case 'jpg':
                case 'jpeg':
                  outputBytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));
                  break;
                default:
                  // PNG for everything else (webp encoding not widely supported in image package)
                  outputBytes = Uint8List.fromList(img.encodePng(image));
              }
              await File(outputPath).writeAsBytes(outputBytes);
            }
          }

          processedCount++;
          setState(() {
            _processProgress = processedCount / totalImages;
          });
        }
      }

      setState(() {
        _isProcessing = false;
        _processStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully processed $processedCount images!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Pick a color from the image at the given position
  Future<void> _pickColorFromImage(Offset localPosition, Size imageWidgetSize) async {
    if (_originalImageBytes == null) return;

    final image = img.decodeImage(_originalImageBytes!);
    if (image == null) return;

    // Calculate the actual pixel position in the image
    // The image is displayed with BoxFit.contain, so we need to calculate the actual bounds
    final imageAspect = image.width / image.height;
    final widgetAspect = imageWidgetSize.width / imageWidgetSize.height;

    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspect > widgetAspect) {
      // Image is wider - fit to width
      scale = image.width / imageWidgetSize.width;
      final displayHeight = imageWidgetSize.width / imageAspect;
      offsetY = (imageWidgetSize.height - displayHeight) / 2;
    } else {
      // Image is taller - fit to height
      scale = image.height / imageWidgetSize.height;
      final displayWidth = imageWidgetSize.height * imageAspect;
      offsetX = (imageWidgetSize.width - displayWidth) / 2;
    }

    // Calculate pixel coordinates
    final pixelX = ((localPosition.dx - offsetX) * scale).round().clamp(0, image.width - 1);
    final pixelY = ((localPosition.dy - offsetY) * scale).round().clamp(0, image.height - 1);

    // Get the pixel color
    final pixel = image.getPixel(pixelX, pixelY);
    final pickedColor = Color.fromARGB(255, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

    // Apply the color
    setState(() {
      if (_eyedropperTarget == 'text') {
        _settings.textColor = pickedColor;
      } else if (_eyedropperTarget == 'bg') {
        _settings.bgColor = pickedColor;
      }
      _eyedropperMode = false;
      _eyedropperTarget = '';
    });

    await _updatePreview();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: pickedColor,
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text('Color picked: #${pickedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Start eyedropper mode
  void _startEyedropper(String target) {
    setState(() {
      _eyedropperMode = true;
      _eyedropperTarget = target;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Click on the preview image to pick a color'),
        action: SnackBarAction(
          label: 'Cancel',
          onPressed: () {
            setState(() {
              _eyedropperMode = false;
              _eyedropperTarget = '';
            });
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _pickColor(String which) async {
    Color currentColor = which == 'text' ? _settings.textColor : _settings.bgColor;

    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pick ${which == 'text' ? 'Text' : 'Background'} Color'),
        content: SingleChildScrollView(
          child: _ColorPicker(
            initialColor: currentColor,
            onColorChanged: (color) => currentColor = color,
            onEyedropperPressed: () {
              Navigator.pop(ctx); // Close dialog first
              _startEyedropper(which);
            },
            hasImage: _originalImageBytes != null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, currentColor),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (which == 'text') {
          _settings.textColor = result;
        } else {
          _settings.bgColor = result;
        }
      });
      await _updatePreview();
    }
  }

  Widget _buildSettingsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Folders Section
          _buildSectionHeader('Folders'),
          _buildFolderRow('Input Folder', _settings.inputFolder, _browseInputFolder),
          _buildFolderRow('Output Folder', _settings.outputFolder, _browseOutputFolder),

          const SizedBox(height: 16),

          // Output Format
          Row(
            children: [
              const Text('Output Format: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _settings.outputFormat,
                items: ['original', 'png', 'jpg', 'webp'].map((f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.toUpperCase()),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _settings.outputFormat = v);
                  }
                },
              ),
            ],
          ),

          const Divider(height: 32),

          // Batches Section
          _buildSectionHeader('Batches'),
          SizedBox(
            height: 150,
            child: Card(
              child: ListView.builder(
                itemCount: _settings.batches.length,
                itemBuilder: (ctx, i) {
                  final batch = _settings.batches[i];
                  return ListTile(
                    selected: i == _selectedBatchIndex,
                    selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    title: Text(batch.phoneNumber),
                    subtitle: Text('Suffix: ${batch.suffix}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteBatch(i),
                    ),
                    onTap: () async {
                      setState(() => _selectedBatchIndex = i);
                      await _updatePreview();
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addBatch,
                icon: const Icon(Icons.add),
                label: const Text('Add Batch'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loadSettings,
                icon: const Icon(Icons.folder_open),
                label: const Text('Load'),
              ),
            ],
          ),

          const Divider(height: 32),

          // Background Settings
          _buildSectionHeader('Background Rectangle'),
          CheckboxListTile(
            title: const Text('Disable Background'),
            value: _settings.disableBackground,
            onChanged: (v) async {
              setState(() => _settings.disableBackground = v ?? false);
              await _updatePreview();
            },
          ),
          if (!_settings.disableBackground) ...[
            _buildAdjustableRow('X Start', _settings.xStart, 10, (v) async {
              setState(() => _settings.xStart = v);
              await _updatePreview();
            }),
            _buildAdjustableRow('Y Start', _settings.yStart, 10, (v) async {
              setState(() => _settings.yStart = v);
              await _updatePreview();
            }),
            _buildAdjustableRow('Width', _settings.width, 10, (v) async {
              setState(() => _settings.width = v);
              await _updatePreview();
            }, min: 1),
            _buildAdjustableRow('Height', _settings.height, 10, (v) async {
              setState(() => _settings.height = v);
              await _updatePreview();
            }, min: 1),
            _buildAdjustableRow('Rotation (deg)', _settings.bgRotation, 5, (v) async {
              setState(() => _settings.bgRotation = v);
              await _updatePreview();
            }, allowNegative: true),
            _buildAdjustableRow('Transparency', _settings.bgTransparency, 10, (v) async {
              setState(() => _settings.bgTransparency = v.clamp(0, 255));
              await _updatePreview();
            }, min: 0, max: 255),
            ListTile(
              title: const Text('Background Color'),
              trailing: GestureDetector(
                onTap: () => _pickColor('bg'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _settings.bgColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],

          const Divider(height: 32),

          // Font/Text Settings
          _buildSectionHeader('Text Overlay'),
          CheckboxListTile(
            title: const Text('Disable Text'),
            value: _settings.disableFont,
            onChanged: (v) async {
              setState(() => _settings.disableFont = v ?? false);
              await _updatePreview();
            },
          ),
          if (!_settings.disableFont) ...[
            // Font Path
            ListTile(
              title: Text(_settings.fontPath.isEmpty
                  ? 'Default Font (Arial)'
                  : path.basename(_settings.fontPath)),
              subtitle: const Text('Font File'),
              trailing: ElevatedButton(
                onPressed: _browseFontFile,
                child: const Text('Browse'),
              ),
            ),
            _buildAdjustableRow('Font Size', _settings.fontSize, 2, (v) async {
              setState(() => _settings.fontSize = v);
              await _updatePreview();
            }, min: 8, max: 200),
            _buildAdjustableRow('Letter Spacing', _settings.letterSpacing, 1, (v) async {
              setState(() => _settings.letterSpacing = v);
              await _updatePreview();
            }, min: 0, max: 50),
            _buildAdjustableRow('Text X', _settings.textX, 10, (v) async {
              setState(() => _settings.textX = v);
              await _updatePreview();
            }),
            _buildAdjustableRow('Text Y', _settings.textY, 10, (v) async {
              setState(() => _settings.textY = v);
              await _updatePreview();
            }),
            _buildAdjustableRow('Rotation (deg)', _settings.textRotation, 5, (v) async {
              setState(() => _settings.textRotation = v);
              await _updatePreview();
            }, allowNegative: true),
            _buildAdjustableRow('Transparency', _settings.textTransparency, 10, (v) async {
              setState(() => _settings.textTransparency = v.clamp(0, 255));
              await _updatePreview();
            }, min: 0, max: 255),
            ListTile(
              title: const Text('Text Color'),
              trailing: GestureDetector(
                onTap: () => _pickColor('text'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _settings.textColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],

          const Divider(height: 32),

          // Watermark Settings
          _buildSectionHeader('Watermark'),
          CheckboxListTile(
            title: const Text('Disable Watermark'),
            value: _settings.disableWatermark,
            onChanged: (v) async {
              setState(() => _settings.disableWatermark = v ?? false);
              await _updatePreview();
            },
          ),
          if (!_settings.disableWatermark) ...[
            ListTile(
              title: Text(_settings.watermarkPath.isEmpty
                  ? 'No watermark selected'
                  : path.basename(_settings.watermarkPath)),
              trailing: ElevatedButton(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    dialogTitle: 'Select Watermark Image',
                    type: FileType.custom,
                    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                  );
                  if (result != null && result.files.single.path != null) {
                    setState(() => _settings.watermarkPath = result.files.single.path!);
                    await _updatePreview();
                  }
                },
                child: const Text('Browse'),
              ),
            ),
            _buildAdjustableRow('Size (width)', _settings.watermarkSize, 10, (v) async {
              setState(() => _settings.watermarkSize = v);
              await _updatePreview();
            }, min: 1, max: 2000),
            _buildAdjustableRow('Position X', _settings.watermarkX, 10, (v) async {
              setState(() => _settings.watermarkX = v);
              await _updatePreview();
            }),
            _buildAdjustableRow('Position Y', _settings.watermarkY, 10, (v) async {
              setState(() => _settings.watermarkY = v);
              await _updatePreview();
            }),
            _buildAdjustableRow('Rotation (deg)', _settings.watermarkRotation, 5, (v) async {
              setState(() => _settings.watermarkRotation = v);
              await _updatePreview();
            }, allowNegative: true),
            _buildAdjustableRow('Transparency', _settings.watermarkTransparency, 10, (v) async {
              setState(() => _settings.watermarkTransparency = v.clamp(0, 255));
              await _updatePreview();
            }, min: 0, max: 255),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFolderRow(String label, String value, VoidCallback onBrowse) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onBrowse,
            child: const Text('Browse'),
          ),
        ],
      ),
    );
  }

  /// Builds a row with +/- buttons for fine adjustment
  Widget _buildAdjustableRow(
    String label,
    int value,
    int step,
    Function(int) onChanged, {
    int min = 0,
    int? max,
    bool allowNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              final newValue = value - step;
              if (allowNegative || newValue >= min) {
                onChanged(max != null ? newValue.clamp(min, max) : newValue.clamp(min, 10000));
              }
            },
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          SizedBox(
            width: 60,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final newValue = value + step;
              onChanged(max != null ? newValue.clamp(min, max) : newValue);
            },
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          // Direct input field
          SizedBox(
            width: 60,
            child: TextField(
              controller: TextEditingController(text: value.toString()),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) {
                  if (max != null) {
                    onChanged(parsed.clamp(min, max));
                  } else if (allowNegative) {
                    onChanged(parsed);
                  } else {
                    onChanged(parsed.clamp(min, 10000));
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Column(
      children: [
        // Preview header
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Preview (${_imageFiles.isEmpty ? 0 : _previewImageIndex + 1}/${_imageFiles.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _imageFiles.isEmpty || _previewImageIndex <= 0
                        ? null
                        : () async {
                            setState(() => _previewImageIndex--);
                            await _updatePreview();
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _imageFiles.isEmpty || _previewImageIndex >= _imageFiles.length - 1
                        ? null
                        : () async {
                            setState(() => _previewImageIndex++);
                            await _updatePreview();
                          },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _updatePreview,
                    tooltip: 'Refresh Preview',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Preview image
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: _eyedropperMode ? Colors.blue : Colors.grey.shade300,
                width: _eyedropperMode ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _previewBytes != null
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return MouseRegion(
                        cursor: _eyedropperMode
                            ? SystemMouseCursors.precise
                            : SystemMouseCursors.basic,
                        child: GestureDetector(
                          onTapDown: _eyedropperMode
                              ? (details) {
                                  _pickColorFromImage(
                                    details.localPosition,
                                    Size(constraints.maxWidth, constraints.maxHeight),
                                  );
                                }
                              : null,
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _previewBytes!,
                                  fit: BoxFit.contain,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                ),
                              ),
                              if (_eyedropperMode)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.blue.withValues(alpha: 0.1),
                                    ),
                                    child: const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.colorize, size: 48, color: Colors.blue),
                                          SizedBox(height: 8),
                                          Text(
                                            'Click to pick color',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _settings.batches.isEmpty
                              ? 'Add a batch to see preview'
                              : _imageFiles.isEmpty
                                  ? 'Select an input folder with images'
                                  : 'Loading preview...',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Process button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isProcessing) ...[
                LinearProgressIndicator(value: _processProgress),
                const SizedBox(height: 8),
                Text(_processStatus),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processAllBatches,
                  icon: Icon(_isProcessing ? Icons.hourglass_top : Icons.play_arrow),
                  label: Text(_isProcessing ? 'Processing...' : 'Process All Batches'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Image Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Help'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Batch Image Editor allows you to process multiple images with text overlays.\n\n'
                      '1. Select an input folder containing images\n'
                      '2. Select an output folder for processed images\n'
                      '3. Add batches with phone numbers and suffixes\n'
                      '4. Adjust background, text, and watermark settings\n'
                      '5. Use +/- buttons to fine-tune positions and sizes\n'
                      '6. Click "Process All Batches" to generate images\n\n'
                      'Each batch creates a subfolder with the suffix name, containing all processed images.',
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
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel - Settings
          SizedBox(
            width: 450,
            child: _buildSettingsPanel(),
          ),

          // Divider
          const VerticalDivider(width: 1),

          // Right panel - Preview
          Expanded(
            child: _buildPreviewPanel(),
          ),
        ],
      ),
    );
  }
}

/// Simple color picker widget with eyedropper support
class _ColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback? onEyedropperPressed;
  final bool hasImage;

  const _ColorPicker({
    required this.initialColor,
    required this.onColorChanged,
    this.onEyedropperPressed,
    this.hasImage = false,
  });

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late Color _color;
  final TextEditingController _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _updateHexField();
  }

  void _updateHexField() {
    _hexController.text = '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  void _parseHexColor(String hex) {
    hex = hex.replaceFirst('#', '').toUpperCase();
    if (hex.length == 6) {
      try {
        final color = Color(int.parse('FF$hex', radix: 16));
        setState(() {
          _color = color;
          widget.onColorChanged(_color);
        });
      } catch (e) {
  debugPrint('[BatchImageEditorScreen] Error: $e');
}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color preview with hex input
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _color,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hex input
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _hexController,
                    decoration: const InputDecoration(
                      labelText: 'Hex',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _parseHexColor,
                    onChanged: (v) {
                      if (v.length == 7 && v.startsWith('#')) {
                        _parseHexColor(v);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Eyedropper button
                if (widget.hasImage && widget.onEyedropperPressed != null)
                  ElevatedButton.icon(
                    onPressed: widget.onEyedropperPressed,
                    icon: const Icon(Icons.colorize, size: 18),
                    label: const Text('Pick from Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // RGB sliders
        _buildColorSlider('Red', (_color.r * 255).round(), Colors.red, (v) {
          setState(() {
            _color = _color.withRed(v);
            widget.onColorChanged(_color);
            _updateHexField();
          });
        }),
        _buildColorSlider('Green', (_color.g * 255).round(), Colors.green, (v) {
          setState(() {
            _color = _color.withGreen(v);
            widget.onColorChanged(_color);
            _updateHexField();
          });
        }),
        _buildColorSlider('Blue', (_color.b * 255).round(), Colors.blue, (v) {
          setState(() {
            _color = _color.withBlue(v);
            widget.onColorChanged(_color);
            _updateHexField();
          });
        }),

        const SizedBox(height: 16),

        // Preset colors
        const Text('Preset Colors:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
            Colors.pink,
            Colors.white,
            Colors.black,
            Colors.grey,
            const Color(0xFF721522), // A1 Chimney red
            const Color(0xFFFF8000), // A1 Chimney orange
            const Color(0xFF1a1a2e), // Dark navy
            const Color(0xFF16213e), // Dark blue
            const Color(0xFF0f3460), // Medium blue
            const Color(0xFFe94560), // Bright red
          ].map((c) => Tooltip(
            message: '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _color = c;
                  widget.onColorChanged(_color);
                  _updateHexField();
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  border: Border.all(
                    color: _color == c ? Colors.blue : Colors.grey,
                    width: _color == c ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSlider(String label, int value, Color color, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: color,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 40, child: Text(value.toString())),
      ],
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }
}
