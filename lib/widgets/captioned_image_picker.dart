import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Model for an image with caption
class CaptionedImage {
  final String fieldName;
  final Uint8List? bytes;
  final String? filePath;
  final String? url;
  String caption;
  final DateTime? capturedAt;

  CaptionedImage({
    required this.fieldName,
    this.bytes,
    this.filePath,
    this.url,
    this.caption = '',
    this.capturedAt,
  });

  bool get hasImage => bytes != null || filePath != null || url != null;

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'caption': caption,
      'captured_at': capturedAt?.toIso8601String(),
    };
  }
}

/// Widget for picking images with captions
class CaptionedImagePicker extends StatefulWidget {
  final String fieldName;
  final String label;
  final CaptionedImage? image;
  final Function(CaptionedImage?) onImageChanged;
  final List<String>? suggestedCaptions;
  final bool required;

  const CaptionedImagePicker({
    super.key,
    required this.fieldName,
    required this.label,
    this.image,
    required this.onImageChanged,
    this.suggestedCaptions,
    this.required = false,
  });

  @override
  State<CaptionedImagePicker> createState() => _CaptionedImagePickerState();
}

class _CaptionedImagePickerState extends State<CaptionedImagePicker> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.image != null) {
      _captionController.text = widget.image!.caption;
    }
  }

  @override
  void didUpdateWidget(CaptionedImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image?.caption != oldWidget.image?.caption) {
      _captionController.text = widget.image?.caption ?? '';
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final image = CaptionedImage(
          fieldName: widget.fieldName,
          bytes: bytes,
          filePath: pickedFile.path,
          caption: _captionController.text,
          capturedAt: DateTime.now(),
        );
        widget.onImageChanged(image);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (widget.image?.hasImage == true)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red.shade400),
                title: Text('Remove Photo', style: TextStyle(color: Colors.red.shade400)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onImageChanged(null);
                  _captionController.clear();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _updateCaption(String caption) {
    if (widget.image != null) {
      widget.image!.caption = caption;
      widget.onImageChanged(widget.image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.image?.hasImage == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (widget.required)
              Text(' *', style: TextStyle(color: Colors.red.shade600)),
          ],
        ),
        const SizedBox(height: 8),

        // Image preview or picker button
        if (hasImage)
          _buildImagePreview()
        else
          _buildPickerButton(),

        // Caption input (shown when image exists)
        if (hasImage) ...[
          const SizedBox(height: 8),
          _buildCaptionInput(),
        ],
      ],
    );
  }

  Widget _buildPickerButton() {
    return InkWell(
      onTap: _showImageSourceDialog,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.required ? Colors.orange.shade300 : Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo,
              size: 32,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add photo',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    Widget imageWidget;

    if (widget.image!.bytes != null) {
      imageWidget = Image.memory(
        widget.image!.bytes!,
        fit: BoxFit.cover,
      );
    } else if (widget.image!.filePath != null) {
      imageWidget = Image.file(
        File(widget.image!.filePath!),
        fit: BoxFit.cover,
      );
    } else if (widget.image!.url != null) {
      imageWidget = Image.network(
        widget.image!.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.broken_image, color: Colors.grey.shade400),
        ),
      );
    } else {
      imageWidget = Container(color: Colors.grey.shade200);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: imageWidget,
          ),
        ),
        // Action buttons
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _buildActionButton(
                icon: Icons.refresh,
                onTap: _showImageSourceDialog,
                tooltip: 'Replace photo',
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.delete,
                onTap: () {
                  widget.onImageChanged(null);
                  _captionController.clear();
                },
                tooltip: 'Remove photo',
                color: Colors.red,
              ),
            ],
          ),
        ),
        // Timestamp
        if (widget.image!.capturedAt != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDateTime(widget.image!.capturedAt!),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color? color,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
        ),
      ),
    );
  }

  Widget _buildCaptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _captionController,
          decoration: const InputDecoration(
            hintText: 'Add caption (optional)',
            prefixIcon: Icon(Icons.edit, size: 20),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          maxLines: 2,
          minLines: 1,
          onChanged: _updateCaption,
        ),

        // Suggested captions
        if (widget.suggestedCaptions?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.suggestedCaptions!.map((caption) {
              return ActionChip(
                label: Text(caption, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _captionController.text = caption;
                  _updateCaption(caption);
                },
                backgroundColor: Colors.grey.shade100,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}

/// Manager class to handle multiple captioned images
class CaptionedImagesManager {
  final Map<String, CaptionedImage> _images = {};

  CaptionedImage? getImage(String fieldName) => _images[fieldName];

  void setImage(String fieldName, CaptionedImage? image) {
    if (image == null) {
      _images.remove(fieldName);
    } else {
      _images[fieldName] = image;
    }
  }

  List<CaptionedImage> get allImages => _images.values.toList();

  Map<String, String> get captions {
    final result = <String, String>{};
    for (final entry in _images.entries) {
      if (entry.value.caption.isNotEmpty) {
        result[entry.key] = entry.value.caption;
      }
    }
    return result;
  }

  void loadCaptions(Map<String, String> captions) {
    for (final entry in captions.entries) {
      if (_images.containsKey(entry.key)) {
        _images[entry.key]!.caption = entry.value;
      }
    }
  }

  void clear() {
    _images.clear();
  }

  int get count => _images.length;
  bool get isEmpty => _images.isEmpty;
  bool get isNotEmpty => _images.isNotEmpty;

  List<Map<String, dynamic>> toCaptionsJson() {
    return _images.values.map((img) => img.toJson()).toList();
  }
}
