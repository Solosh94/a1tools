// Inspection Form Screen
//
// Form for creating new inspection reports with photos.

// ignore_for_file: deprecated_member_use
// RadioListTile groupValue/onChanged deprecation will be addressed when migrating to Flutter 3.32+ RadioGroup

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import 'inspection_models.dart';
import 'inspection_service.dart';

class InspectionFormScreen extends StatefulWidget {
  final String username;
  final String firstName;
  final String lastName;
  final VoidCallback? onInspectionCreated;

  const InspectionFormScreen({
    super.key,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.onInspectionCreated,
  });

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  static const Color _accent = AppColors.accent;

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _issuesController = TextEditingController();
  final _recommendationsController = TextEditingController();

  String _chimneyType = ChimneyTypes.all.first;
  String _condition = ConditionRatings.all.first;
  String? _state;

  // Job fields
  String _jobCategory = JobCategories.allCategories.first;
  String? _jobType;
  String _completionStatus = CompletionStatus.completed;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _discountUsed = false;

  final List<_PhotoItem> _photos = [];
  bool _submitting = false;
  String? _error;

  static const int _maxPhotos = 50; // Aligned with InspectionService.maxPhotosPerInspection

  @override
  void initState() {
    super.initState();
    // Set default job type based on initial category
    final types = JobCategories.getTypesForCategory(_jobCategory);
    if (types.isNotEmpty) {
      _jobType = types.first;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _zipCodeController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _descriptionController.dispose();
    _issuesController.dispose();
    _recommendationsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum $_maxPhotos photos allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Data = base64Encode(bytes);

      setState(() {
        _photos.add(_PhotoItem(
          bytes: bytes,
          base64Data: base64Data,
          filename: image.name,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEndTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endTime ?? now,
      firstDate: _startTime ?? now.subtract(const Duration(days: 30)),
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime == null) {
      setState(() => _error = 'Please select a start time');
      return;
    }
    if (_endTime == null) {
      setState(() => _error = 'Please select an end time');
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      setState(() => _error = 'End time must be after start time');
      return;
    }
    if (_jobType == null) {
      setState(() => _error = 'Please select a job type');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final photos = _photos
          .map((p) => PendingPhoto(
                base64Data: p.base64Data,
                filename: p.filename,
              ))
          .toList();

      final result = await InspectionService.instance.submitInspection(
        username: widget.username,
        firstName: widget.firstName,
        lastName: widget.lastName,
        address: _addressController.text.trim(),
        state: _state,
        zipCode: _zipCodeController.text.trim(),
        chimneyType: _chimneyType,
        condition: _condition,
        description: _descriptionController.text.trim(),
        issues: _issuesController.text.trim(),
        recommendations: _recommendationsController.text.trim(),
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        jobCategory: _jobCategory,
        jobType: _jobType!,
        completionStatus: _completionStatus,
        startTime: _startTime!,
        endTime: _endTime!,
        localSubmitTime: DateTime.now(),
        discountUsed: _discountUsed,
        photos: photos,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Inspection submitted successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onInspectionCreated?.call();
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = result.error ?? 'Failed to submit inspection';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormat = DateFormat('MMM d, yyyy h:mm a');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('New Inspection'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Error message
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Technician Info (read only)
            _buildSectionHeader('Technician', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Row(
                children: [
                  const Icon(Icons.person, color: _accent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '${widget.firstName} ${widget.lastName}'.trim().isEmpty
                        ? widget.username
                        : '${widget.firstName} ${widget.lastName}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Job Category and Type
            _buildSectionHeader('Job Details *', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _jobCategory,
                    decoration: _inputDecoration('Job Category', isDark),
                    items: JobCategories.allCategories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _jobCategory = value;
                          final types = JobCategories.getTypesForCategory(value);
                          _jobType = types.isNotEmpty ? types.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _jobType,
                    decoration: _inputDecoration('Job Type', isDark),
                    items: JobCategories.getTypesForCategory(_jobCategory)
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _jobType = value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a job type';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Time Section
            _buildSectionHeader('Job Time *', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeButton(
                          label: 'Start Time',
                          value: _startTime != null ? timeFormat.format(_startTime!) : 'Select',
                          onTap: _pickStartTime,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeButton(
                          label: 'End Time',
                          value: _endTime != null ? timeFormat.format(_endTime!) : 'Select',
                          onTap: _pickEndTime,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  if (_startTime != null && _endTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Duration: ${_formatDuration(_endTime!.difference(_startTime!))}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Customer Info Section
            _buildSectionHeader('Customer Info (optional)', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: [
                  TextFormField(
                    controller: _customerNameController,
                    decoration: _inputDecoration('Customer Name', isDark),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerPhoneController,
                    decoration: _inputDecoration('Phone Number', isDark),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Inspection Details Section
            _buildSectionHeader('Location Details', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: [
                  TextFormField(
                    controller: _addressController,
                    decoration: _inputDecoration('Job Site Address *', isDark),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _state,
                          decoration: _inputDecoration('State', isDark),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Select State'),
                            ),
                            ...USStates.all.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() => _state = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _zipCodeController,
                          decoration: _inputDecoration('Zip Code', isDark),
                          keyboardType: TextInputType.number,
                          maxLength: 5,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Chimney Details Section
            _buildSectionHeader('Chimney Details', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _chimneyType,
                          decoration: _inputDecoration('Chimney Type', isDark),
                          items: ChimneyTypes.all
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _chimneyType = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _condition,
                          decoration: _inputDecoration('Condition', isDark),
                          items: ConditionRatings.all
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _condition = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      ConditionRatings.getDescription(_condition),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getConditionColor(_condition),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Job Description and Notes Section
            _buildSectionHeader('Job Notes', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration('Job Description', isDark),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _issuesController,
                    decoration: _inputDecoration('Issues Noted *', isDark),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please describe the issues found';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _recommendationsController,
                    decoration: _inputDecoration('Recommendations', isDark),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Completion Status
            _buildSectionHeader('Job Status *', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                children: CompletionStatus.all.map((status) {
                  return RadioListTile<String>(
                    title: Text(CompletionStatus.getDisplay(status)),
                    value: status,
                    groupValue: _completionStatus,
                    activeColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _completionStatus = value);
                      }
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Discount Section
            _buildSectionHeader('Discount', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: SwitchListTile(
                title: const Text('Discount Used?'),
                subtitle: Text(
                  _discountUsed ? 'Yes, a discount was applied' : 'No discount applied',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                value: _discountUsed,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                activeThumbColor: _accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() => _discountUsed = value);
                },
              ),
            ),

            const SizedBox(height: 20),

            // Photos Section
            _buildSectionHeader('Photos (${_photos.length}/$_maxPhotos)', isDark),
            const SizedBox(height: 8),
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_photos.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No photos added yet',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < _photos.length; i++)
                          _buildPhotoThumbnail(_photos[i], i, isDark),
                      ],
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _photos.length >= _maxPhotos ? null : _showPhotoOptions,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Inspection',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accent),
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          borderRadius: BorderRadius.circular(8),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: _accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(_PhotoItem photo, int index, bool isDark) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              photo.bytes,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Good':
        return Colors.green;
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return Colors.deepOrange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }
}

class _PhotoItem {
  final Uint8List bytes;
  final String base64Data;
  final String filename;

  _PhotoItem({
    required this.bytes,
    required this.base64Data,
    required this.filename,
  });
}
