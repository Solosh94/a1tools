// Comprehensive Inspection Report Form
//
// Multi-step wizard for creating detailed chimney inspection reports.
// Supports Electric, Furnace, Masonry Fireplace, Built-In Fireplace, and Wood Stove systems.
// Enhanced with Workiz integration, invoice items, address autocomplete, and draft saving.

// ignore_for_file: deprecated_member_use
// RadioListTile groupValue/onChanged deprecation will be addressed when migrating to Flutter 3.32+ RadioGroup

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import 'inspection_data.dart';
import 'inspection_models.dart';
import 'inspection_pdf_generator.dart';
import 'inspection_report_service.dart';
import 'inspection_draft_service.dart';
import '../inventory/invoice_items_service.dart';
import '../integration/workiz_service.dart';
import '../../widgets/invoice_items_picker.dart';
import '../../widgets/captioned_image_picker.dart';

class InspectionReportForm extends StatefulWidget {
  final String username;
  final String firstName;
  final String lastName;
  final String role;
  final VoidCallback? onInspectionCreated;

  // Workiz location for this inspection
  final int? workizLocationId;
  final String? workizLocationCode;
  final String? workizLocationName;

  const InspectionReportForm({
    super.key,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.onInspectionCreated,
    this.workizLocationId,
    this.workizLocationCode,
    this.workizLocationName,
  });

  @override
  State<InspectionReportForm> createState() => _InspectionReportFormState();
}

class _InspectionReportFormState extends State<InspectionReportForm> {
  static const Color _accent = AppColors.accent;
  static const Color _red = Color(0xFFDB2323);

  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  final InspectionDraftService _draftService = InspectionDraftService();

  late InspectionFormData _formData;
  int _currentStep = 0;
  bool _submitting = false;
  String? _error;

  // Track which steps have attempted to proceed (for showing validation errors)
  final Set<int> _attemptedSteps = {};

  // Workiz integration
  WorkizJob? _selectedWorkizJob;
  final WorkizService _workizService = WorkizService();

  // Job lookup state
  final TextEditingController _jobIdController = TextEditingController();
  bool _isLookingUpJob = false;
  String? _jobLookupError;

  // Invoice items selection
  final InvoiceItemsSelection _invoiceItems = InvoiceItemsSelection();

  // Captioned images
  final CaptionedImagesManager _imagesManager = CaptionedImagesManager();

  // Auto-save timer
  DateTime? _lastAutoSave;

  // Steps based on the HTML template structure
  final List<String> _stepTitles = [
    'Job Info',
    'Client Info',
    'System Type',
    'System Details',
    'Chimney/Flue',
    'Exterior (Level 2+)',
    'Notes & Sign',
  ];

  @override
  void initState() {
    super.initState();
    _formData = InspectionFormData(
      inspectorName: '${widget.firstName} ${widget.lastName}'.trim(),
    );
    // Set up Workiz service context
    _workizService.setUserContext(widget.username, widget.workizLocationCode);
    _checkForAutoSave();
  }

  Future<void> _checkForAutoSave() async {
    final autoSave = await _draftService.getAutoSave(widget.username);
    if (autoSave != null && mounted) {
      final autoSaveTime = await _draftService.getAutoSaveTime(widget.username);
      if (!mounted) return;
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Draft?'),
          content: Text(
            'You have an auto-saved draft from ${autoSaveTime != null ? DateFormat('MMM d, h:mm a').format(autoSaveTime) : 'earlier'}. Would you like to restore it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Start Fresh'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );

      if (shouldRestore == true && mounted) {
        _restoreFromAutoSave(autoSave);
      } else if (shouldRestore == false) {
        await _draftService.clearAutoSave(widget.username);
      }
    }
  }

  void _restoreFromAutoSave(Map<String, dynamic> data) {
    setState(() {
      _formData.firstName = data['first_name'] ?? '';
      _formData.lastName = data['last_name'] ?? '';
      _formData.address1 = data['address1'] ?? '';
      _formData.address2 = data['address2'];
      _formData.city = data['city'] ?? '';
      _formData.state = data['state'] ?? '';
      _formData.zipCode = data['zip_code'] ?? '';
      _formData.phone = data['phone'] ?? '';
      _formData.email1 = data['email1'] ?? '';
      _formData.inspectionLevel = data['inspection_level'] ?? InspectionLevels.level1;
      _formData.reasonForInspection = data['reason_for_inspection'] ?? 'Annual Inspection';
      _formData.systemType = data['system_type'] ?? '';
      _formData.jobId = data['job_id'];
      _formData.inspectorNote = data['inspector_note'];

      // Restore Workiz integration data if present
      final workizSerial = data['workiz_job_serial'];
      final workizUuid = data['workiz_job_uuid'];
      final workizClientId = data['workiz_client_id'];
      if (workizSerial != null || workizUuid != null) {
        _formData.workizJobSerial = workizSerial;
        _formData.workizJobUuid = workizUuid;
        _formData.workizClientId = workizClientId;
        _jobIdController.text = workizSerial ?? '';
      }

      // Restore invoice items if present
      if (data['invoice_items'] != null) {
        _invoiceItems.loadFromJson(data['invoice_items'] as List);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Draft restored successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _autoSave() async {
    final now = DateTime.now();
    if (_lastAutoSave != null && now.difference(_lastAutoSave!).inSeconds < 30) {
      return; // Don't auto-save more than once every 30 seconds
    }

    final data = _buildFormDataForSave();
    await _draftService.autoSave(widget.username, data);
    _lastAutoSave = now;
  }

  Map<String, dynamic> _buildFormDataForSave() {
    return {
      'first_name': _formData.firstName,
      'last_name': _formData.lastName,
      'address1': _formData.address1,
      'address2': _formData.address2,
      'city': _formData.city,
      'state': _formData.state,
      'zip_code': _formData.zipCode,
      'phone': _formData.phone,
      'email1': _formData.email1,
      'inspection_level': _formData.inspectionLevel,
      'reason_for_inspection': _formData.reasonForInspection,
      'system_type': _formData.systemType,
      'job_id': _formData.jobId,
      'inspector_note': _formData.inspectorNote,
      'invoice_items': _invoiceItems.toJson(),
      'workiz_job_serial': _selectedWorkizJob?.workizSerialId,
      'workiz_job_uuid': _selectedWorkizJob?.workizUuid,
      'workiz_client_id': _selectedWorkizJob?.clientId,
    };
  }

  void _populateFromWorkizJob(WorkizJob job) {
    if (job.id == -1) {
      // Clear selection signal
      setState(() {
        _selectedWorkizJob = null;
        _formData.workizJobUuid = null;
        _formData.workizJobSerial = null;
        _formData.workizClientId = null;
      });
      return;
    }

    setState(() {
      _selectedWorkizJob = job;
      _formData.firstName = job.clientFirstName ?? '';
      _formData.lastName = job.clientLastName ?? '';
      _formData.address1 = job.address ?? '';
      _formData.city = job.city ?? '';
      _formData.state = job.state ?? '';
      _formData.zipCode = job.zipCode ?? '';
      _formData.phone = job.clientPhone ?? '';
      _formData.email1 = job.clientEmail ?? '';
      _formData.jobId = job.workizSerialId;
      _jobIdController.text = job.workizSerialId ?? '';
      // Set Workiz integration fields for API submission
      _formData.workizJobUuid = job.workizUuid;
      _formData.workizJobSerial = job.workizSerialId;
      _formData.workizClientId = job.clientId;
      _jobLookupError = null;
    });
  }

  /// Look up a job by its ID/reference number and populate the form
  Future<void> _lookupJobById(String jobId) async {
    final trimmedId = jobId.trim();
    if (trimmedId.isEmpty) {
      setState(() => _jobLookupError = null);
      return;
    }

    if (trimmedId.length < 3) {
      setState(() => _jobLookupError = 'Enter at least 3 characters');
      return;
    }

    setState(() {
      _isLookingUpJob = true;
      _jobLookupError = null;
    });

    try {
      // Search for jobs matching this ID
      final jobs = await _workizService.searchJobs(
        trimmedId,
        locationCode: widget.workizLocationCode,
      );

      if (!mounted) return;

      if (jobs.isEmpty) {
        setState(() {
          _isLookingUpJob = false;
          _jobLookupError = 'No job found with ID "$trimmedId"';
        });
        return;
      }

      // If we found exactly one job, auto-select it
      if (jobs.length == 1) {
        _populateFromWorkizJob(jobs.first);
        setState(() => _isLookingUpJob = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Loaded job: ${jobs.first.displayLabel}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // If multiple jobs found, show selection dialog
      setState(() => _isLookingUpJob = false);
      _showJobSelectionDialog(jobs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLookingUpJob = false;
          _jobLookupError = 'Lookup failed: ${e.toString()}';
        });
      }
    }
  }

  /// Show a dialog to select from multiple matching jobs
  void _showJobSelectionDialog(List<WorkizJob> jobs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Multiple Jobs Found'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.1),
                  child: Text(
                    job.workizSerialId?.substring(0, 1).toUpperCase() ?? '#',
                    style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(job.displayLabel),
                subtitle: Text(
                  job.fullAddress.isNotEmpty ? job.fullAddress : job.clientFullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _populateFromWorkizJob(job);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _jobIdController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      // Validate current step before proceeding
      final missingFields = _getMissingFieldsForStep(_currentStep);
      if (missingFields.isNotEmpty) {
        // Mark this step as attempted to show validation errors
        setState(() => _attemptedSteps.add(_currentStep));

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Please complete all required fields:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(missingFields.join(', '), style: const TextStyle(fontSize: 13)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // Don't proceed to next step
      }

      // Auto-save when moving to next step
      _autoSave();

      // Skip exterior step for Level 1
      if (_currentStep == 4 && _formData.inspectionLevel == InspectionLevels.level1) {
        setState(() => _currentStep = 6);
        _pageController.animateToPage(6,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        setState(() => _currentStep++);
        _pageController.nextPage(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      // Skip exterior step for Level 1
      if (_currentStep == 6 && _formData.inspectionLevel == InspectionLevels.level1) {
        setState(() => _currentStep = 4);
        _pageController.animateToPage(4,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        setState(() => _currentStep--);
        _pageController.previousPage(
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  /// Check which required fields are missing and return a list of field names
  List<String> _getMissingRequiredFields() {
    final missing = <String>[];

    // Step 1: Job Info - System Type is required
    if (_formData.systemType.isEmpty) missing.add('System Type');

    // Step 2: Client Info - required fields
    if (_formData.firstName.trim().isEmpty) missing.add('First Name');
    if (_formData.lastName.trim().isEmpty) missing.add('Last Name');
    if (_formData.address1.trim().isEmpty) missing.add('Street Address');
    if (_formData.city.trim().isEmpty) missing.add('City');
    if (_formData.state.trim().isEmpty) missing.add('State');
    if (_formData.zipCode.trim().isEmpty) missing.add('Zip Code');

    // Required images - Exterior Home Image is always required
    if (_formData.exteriorHomeImage == null) missing.add('Exterior Home Image');

    // Step 4: System-specific required fields based on system type
    switch (_formData.systemType) {
      case 'Electric':
        if (_formData.electricFireplaceCondition == null) {
          missing.add('Electric Fireplace Condition');
        }
        break;
      case 'Furnace':
        if (_formData.burningType == null) missing.add('Burning Type');
        if (_formData.furnaceVisualInspection == null) {
          missing.add('Furnace Visual Inspection');
        }
        break;
      case 'Masonry Fireplace':
        if (_formData.fireboxCondition == null) missing.add('Firebox Condition');
        if (_formData.damper == null) missing.add('Damper Condition');
        if (_formData.smokeChamber == null) missing.add('Smoke Chamber');
        break;
      case 'Built-In Fireplace':
        // Built-in fireplaces don't have a type field - dimensions are optional
        break;
      case 'Wood Stove':
        if (_formData.woodStoveType == null) missing.add('Wood Stove Type');
        if (_formData.stoveCondition == null) missing.add('Stove Condition');
        break;
    }

    // System-specific required images
    switch (_formData.systemType) {
      case 'Electric':
        if (_formData.electricFireplaceImage == null) missing.add('Electric Fireplace Image');
        break;
      case 'Furnace':
        if (_formData.furnaceImage == null) missing.add('Furnace Image');
        break;
      case 'Masonry Fireplace':
        if (_formData.masonryFireplaceImage == null) missing.add('Firebox Image');
        break;
      case 'Built-In Fireplace':
        if (_formData.builtInFireplaceImage == null) missing.add('Built-In Fireplace Image');
        break;
      case 'Wood Stove':
        if (_formData.woodStoveImage == null) missing.add('Wood Stove Image');
        break;
    }

    // Step 5: Chimney/Flue required fields
    if (_formData.systemType.isNotEmpty && _formData.systemType != 'Electric') {
      // Cleanout Door is only required for Masonry / Bricks flue type
      if (_formData.flueVentilationType == 'Masonry / Bricks' && _formData.cleanoutDoor == null) {
        missing.add('Cleanout Door');
      }
      if (_formData.chimneyLiner == null) missing.add('Chimney Liner');
    }

    // Step 6: Exterior (Level 2+) - required if Level 2 or 3
    if (_formData.inspectionLevel != InspectionLevels.level1 &&
        _formData.systemType.isNotEmpty &&
        _formData.systemType != 'Electric') {
      if (_formData.flueVentilationType == null) {
        missing.add('Flue/Ventilation Type');
      }
    }

    return missing;
  }

  /// Get missing fields for a specific step
  List<String> _getMissingFieldsForStep(int step) {
    final missing = <String>[];

    switch (step) {
      case 0: // Job Info - no required fields (inspector pre-filled, date auto-filled)
        break;

      case 1: // Client Info
        if (_formData.firstName.trim().isEmpty) missing.add('First Name');
        if (_formData.lastName.trim().isEmpty) missing.add('Last Name');
        if (_formData.address1.trim().isEmpty) missing.add('Street Address');
        if (_formData.city.trim().isEmpty) missing.add('City');
        if (_formData.state.trim().isEmpty) missing.add('State');
        if (_formData.zipCode.trim().isEmpty) missing.add('Zip Code');
        // Required image for client info step
        if (_formData.exteriorHomeImage == null) missing.add('Exterior Home Image');
        break;

      case 2: // System Type
        if (_formData.systemType.isEmpty) missing.add('System Type');
        break;

      case 3: // System Details - ALL fields required
        switch (_formData.systemType) {
          case 'Electric':
            if (_formData.electricFireplaceCondition == null) missing.add('Electric Fireplace Condition');
            if (_formData.electricFireplaceImage == null) missing.add('Electric Fireplace Image');
            break;
          case 'Furnace':
            if (_formData.burningType == null) missing.add('Burning Type');
            if (_formData.furnaceVisualInspection == null) missing.add('Furnace Visual Inspection');
            if (_formData.furnaceVenting == null) missing.add('Venting');
            if (_formData.furnaceClearance == null) missing.add('Clearance');
            if (_formData.furnaceImage == null) missing.add('Furnace Image');
            break;
          case 'Masonry Fireplace':
            if (_formData.fireplaceClearanceToCombustibles == null) missing.add('Clearance to Combustibles');
            if (_formData.fireboxCondition == null) missing.add('Firebox Condition');
            if (_formData.ashDump == null) missing.add('Ash Dump');
            if (_formData.gasLine == null) missing.add('Gas Line');
            if (_formData.damper == null) missing.add('Damper');
            if (_formData.smokeChamber == null) missing.add('Smoke Chamber');
            if (_formData.masonrySoot == null) missing.add('Soot Condition');
            if (_formData.masonryFireplaceImage == null) missing.add('Firebox Image');
            break;
          case 'Built-In Fireplace':
            if (_formData.builtInHearth == null) missing.add('Hearth');
            if (_formData.builtInClearance == null) missing.add('Clearance to Combustibles');
            if (_formData.builtInDamper == null) missing.add('Damper');
            if (_formData.builtInSoot == null) missing.add('Soot Condition');
            if (_formData.builtInFireplaceImage == null) missing.add('Built-In Fireplace Image');
            break;
          case 'Wood Stove':
            if (_formData.woodStoveType == null) missing.add('Wood Stove Type');
            if (_formData.stoveCondition == null) missing.add('Stove Condition');
            if (_formData.stoveClearanceToCombustibles == null) missing.add('Stove Clearance');
            if (_formData.stoveSootCondition == null) missing.add('Stove Soot Condition');
            if (_formData.woodStoveImage == null) missing.add('Wood Stove Image');
            break;
        }
        break;

      case 4: // Chimney/Flue - ALL fields required
        if (_formData.systemType.isNotEmpty && _formData.systemType != 'Electric') {
          if (_formData.flueVentilationType == null) missing.add('Flue/Ventilation Type');
          if (_formData.chimneyLiner == null) missing.add('Chimney Liner');
          // Cleanout door required for Masonry / Bricks flue type
          if (_formData.flueVentilationType == 'Masonry / Bricks' && _formData.cleanoutDoor == null) {
            missing.add('Cleanout Door');
          }
        }
        break;

      case 5: // Exterior (Level 2+) - fields required based on system/flue type
        if (_formData.inspectionLevel != InspectionLevels.level1 &&
            _formData.systemType.isNotEmpty &&
            _formData.systemType != 'Electric') {
          if (_formData.chimneyHeightFromRoofLine == null) missing.add('Chimney Height From Roof Line');
          if (_formData.chimneyCricket == null) missing.add('Chimney Cricket');
          if (_formData.flushingCondition == null) missing.add('Flashing Condition');
          // These masonry-specific fields are only required when masonry chimney is present
          final isMasonryChimney = _formData.flueVentilationType == 'Masonry / Bricks' ||
              _formData.systemType == 'Masonry Fireplace';
          if (isMasonryChimney) {
            if (_formData.masonryWorkCondition == null) missing.add('Masonry Work Condition');
            if (_formData.chimneyCrownCondition == null) missing.add('Chimney Crown Condition');
            if (_formData.chimneyRainCap == null) missing.add('Chimney Rain Cap');
          }
          if (_formData.chimneySparkArrestor == null) missing.add('Chimney Spark Arrestor');
        }
        break;

      case 6: // Notes & Sign - no required fields
        break;
    }

    return missing;
  }

  /// Check if user attempted to go next on this step (for showing errors)
  bool _showErrorsForStep(int step) => _attemptedSteps.contains(step);

  /// Get the step number where a field is located
  int _getStepForMissingField(String fieldName) {
    // Step 0: Job Info
    if (fieldName == 'System Type') return 2;

    // Step 1: Client Info (including Exterior Home Image)
    if (['First Name', 'Last Name', 'Street Address', 'City', 'State', 'Zip Code',
        'Exterior Home Image'].contains(fieldName)) {
      return 1;
    }

    // Step 3: System Details (including system-specific images)
    if ([
      'Electric Fireplace Condition', 'Electric Fireplace Image',
      'Burning Type', 'Furnace Visual Inspection', 'Vent Connector', 'Furnace Image',
      'Clearance to Combustibles', 'Firebox Condition', 'Ash Dump', 'Gas Line',
      'Damper', 'Smoke Chamber', 'Soot Condition', 'Firebox Image',
      'Hearth', 'Stove Soot Condition', 'Built-In Fireplace Image',
      'Wood Stove Type', 'Stove Condition', 'Stove Clearance', 'Wood Stove Image'
    ].contains(fieldName)) {
      return 3;
    }

    // Step 4: Chimney/Flue
    if ([
      'Flue/Ventilation Type', 'Chimney Liner', 'Cleanout Door'
    ].contains(fieldName)) {
      return 4;
    }

    // Step 5: Exterior
    if ([
      'Chimney Height From Roof Line', 'Chimney Cricket', 'Flashing Condition',
      'Masonry Work Condition', 'Chimney Crown Condition', 'Chimney Rain Cap',
      'Chimney Spark Arrestor'
    ].contains(fieldName)) {
      return 5;
    }

    return 0;
  }

  Future<void> _submit() async {
    // Check required fields first and show specific errors
    final missingFields = _getMissingRequiredFields();
    if (missingFields.isNotEmpty) {
      // Navigate to the step where the first missing field is located
      final firstMissing = missingFields.first;
      final targetStep = _getStepForMissingField(firstMissing);
      if (_currentStep != targetStep) {
        setState(() => _currentStep = targetStep);
        _pageController.animateToPage(targetStep,
            duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }

      // Show snackbar with specific missing fields
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Missing Required Fields:', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(missingFields.join(', '), style: const TextStyle(fontSize: 13)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Also validate form to highlight the fields
      _formKey.currentState!.validate();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Show options: Submit only, Generate PDF, or Both (with SMS option)
    final options = await _showSubmitOptions();
    if (options == null || options.action == null) return;

    final action = options.action!;
    final sendSms = options.sendSms;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      bool submitSuccess = true;
      bool smsSent = false;

      // Submit to API if requested
      if (action == 'submit' || action == 'both') {
        // Debug: Log invoice items being submitted
        debugPrint('[InspectionReportForm] Submitting with ${_invoiceItems.count} invoice items');
        if (_invoiceItems.isNotEmpty) {
          debugPrint('[InspectionReportForm] Invoice items total: ${_invoiceItems.totalDisplay}');
        }
        debugPrint('[InspectionReportForm] SMS to client: $sendSms');

        final result = await InspectionReportService.instance.submitReport(
          username: widget.username,
          formData: _formData,
          invoiceItems: _invoiceItems.isNotEmpty ? _invoiceItems.toJson() : null,
          skipSms: !sendSms, // Skip SMS if user didn't check the box
        );
        submitSuccess = result.success;
        smsSent = result.workflowResult?.smsSent ?? false;
        if (!submitSuccess && mounted) {
          setState(() => _error = result.error ?? 'Failed to submit report');
        }
      }

      // Generate PDF if requested
      if (action == 'pdf' || action == 'both') {
        await _showPdfOptions();
      }

      if (mounted && submitSuccess) {
        // Clear auto-save on successful submission
        await _draftService.clearAutoSave(widget.username);

        if (!mounted) return;

        // Build success message
        String successMessage = action == 'pdf'
            ? 'PDF generated successfully!'
            : 'Inspection report submitted successfully!';
        if (sendSms && smsSent) {
          successMessage += '\nSMS sent to ${_formData.firstName}';
        } else if (sendSms && !smsSent) {
          successMessage += '\n(SMS could not be sent)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        if (action != 'pdf') {
          widget.onInspectionCreated?.call();
        }
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<({String? action, bool sendSms})?> _showSubmitOptions() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool sendSmsToClient = _formData.phone.isNotEmpty == true; // Default to true if phone exists

    return showModalBottomSheet<({String? action, bool sendSms})>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'What would you like to do?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // SMS notification option
              if (_formData.phone.isNotEmpty == true)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF22F46).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF22F46).withValues(alpha: 0.3),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: sendSmsToClient,
                    onChanged: (value) => setModalState(() => sendSmsToClient = value ?? false),
                    activeColor: const Color(0xFFF22F46),
                    title: const Row(
                      children: [
                        Icon(Icons.sms, color: Color(0xFFF22F46), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Send SMS to client',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Notify ${_formData.firstName} at ${_formData.phone}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_upload, color: _accent),
                ),
                title: const Text('Submit Report'),
                subtitle: const Text('Save to server only'),
                onTap: () => Navigator.pop(ctx, (action: 'submit', sendSms: sendSmsToClient)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                ),
                title: const Text('Generate PDF Only'),
                subtitle: const Text('Create PDF without saving to server'),
                onTap: () => Navigator.pop(ctx, (action: 'pdf', sendSms: false)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.done_all, color: Colors.green),
                ),
                title: const Text('Submit & Generate PDF'),
                subtitle: const Text('Save to server and create PDF'),
                onTap: () => Navigator.pop(ctx, (action: 'both', sendSms: sendSmsToClient)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPdfOptions() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'PDF Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share, color: _accent),
              title: const Text('Share PDF'),
              subtitle: const Text('Send via email, messaging, etc.'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print PDF'),
              subtitle: const Text('Send to a printer'),
              onTap: () => Navigator.pop(ctx, 'print'),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: const Text('Save PDF'),
              subtitle: const Text('Save to device'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Prepare image list for PDF
      final images = _imagesManager.allImages;

      switch (action) {
        case 'share':
          await InspectionPdfGenerator.generateAndShare(
            _formData,
            invoiceItems: _invoiceItems.isNotEmpty ? _invoiceItems : null,
            images: images.isNotEmpty ? images : null,
            workizJobSerial: _selectedWorkizJob?.workizSerialId,
          );
          break;
        case 'print':
          await InspectionPdfGenerator.generateAndPrint(
            _formData,
            invoiceItems: _invoiceItems.isNotEmpty ? _invoiceItems : null,
            images: images.isNotEmpty ? images : null,
            workizJobSerial: _selectedWorkizJob?.workizSerialId,
          );
          break;
        case 'save':
          final path = await InspectionPdfGenerator.generateAndSave(
            _formData,
            invoiceItems: _invoiceItems.isNotEmpty ? _invoiceItems : null,
            images: images.isNotEmpty ? images : null,
            workizJobSerial: _selectedWorkizJob?.workizSerialId,
          );
          if (mounted && path != null) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('PDF saved to: $path')),
            );
            return;
          }
          break;
      }
      if (mounted) Navigator.pop(context); // Close loading
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: Text('${_stepTitles[_currentStep]} (${_currentStep + 1}/${_stepTitles.length})'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _previousStep,
              child: const Text('Back'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(isDark),

            // Error message
            if (_error != null)
              Container(
                margin: const EdgeInsets.all(16),
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
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildJobInfoStep(isDark),
                  _buildClientInfoStep(isDark),
                  _buildSystemTypeStep(isDark),
                  _buildSystemDetailsStep(isDark),
                  _buildChimneyFlueStep(isDark),
                  _buildExteriorStep(isDark),
                  _buildNotesSignStep(isDark),
                ],
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(_stepTitles.length, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          // Skip exterior for level 1
          final isSkipped = index == 5 && _formData.inspectionLevel == InspectionLevels.level1;

          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isSkipped
                    ? Colors.grey.withValues(alpha: 0.3)
                    : isCompleted || isCurrent
                        ? _accent
                        : isDark
                            ? Colors.white24
                            : Colors.black12,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    final isLastStep = _currentStep == _stepTitles.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Previous'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _submitting ? null : (isLastStep ? _submit : _nextStep),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isLastStep ? 'Submit Report' : 'Continue',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 1: JOB INFO ====================
  Widget _buildJobInfoStep(bool isDark) {
    // Initialize controller text if form data has a job ID but controller is empty
    if (_formData.jobId != null && _formData.jobId!.isNotEmpty && _jobIdController.text.isEmpty) {
      _jobIdController.text = _formData.jobId!;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Job ID input field with lookup
        _buildSectionHeader('Job ID', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _jobIdController,
                      decoration: _inputDecoration('Enter Job ID / Reference Number', isDark).copyWith(
                        suffixIcon: _isLookingUpJob
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => _formData.jobId = value,
                      onFieldSubmitted: (value) => _lookupJobById(value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLookingUpJob
                          ? null
                          : () => _lookupJobById(_jobIdController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Lookup'),
                    ),
                  ),
                ],
              ),
              // Error message
              if (_jobLookupError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: _red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _jobLookupError!,
                        style: const TextStyle(color: _red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              // Success - show selected job info
              if (_selectedWorkizJob != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Job Loaded: ${_selectedWorkizJob!.displayLabel}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                            if (_selectedWorkizJob!.clientFullName.isNotEmpty)
                              Text(
                                _selectedWorkizJob!.clientFullName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: () {
                          setState(() {
                            _selectedWorkizJob = null;
                            _jobIdController.clear();
                            _formData.jobId = null;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Clear job',
                      ),
                    ],
                  ),
                ),
              ],
              // Help text
              if (_selectedWorkizJob == null && _jobLookupError == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Enter a job number and tap Lookup to auto-fill client details',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Inspector', isDark),
        _buildCard(
          isDark: isDark,
          child: Row(
            children: [
              const Icon(Icons.person, color: _accent, size: 20),
              const SizedBox(width: 12),
              Text(
                _formData.inspectorName.isEmpty ? widget.username : _formData.inspectorName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Inspection Level *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: InspectionLevels.all.map((level) {
              return RadioListTile<String>(
                title: Text(level),
                subtitle: Text(
                  InspectionLevels.getDescription(level),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                ),
                value: level,
                groupValue: _formData.inspectionLevel,
                activeColor: _accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  if (value != null) setState(() => _formData.inspectionLevel = value);
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Reason for Inspection', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _formData.reasonForInspection,
                decoration: _inputDecoration('Select Reason', isDark),
                items: InspectionReasons.all
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _formData.reasonForInspection = value);
                },
              ),
              if (_formData.reasonForInspection == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  decoration: _inputDecoration('Specify reason', isDark),
                  onChanged: (value) => _formData.otherReason = value,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Inspection Date & Time', isDark),
        _buildCard(
          isDark: isDark,
          child: Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: 'Date',
                  value: DateFormat('MMM d, yyyy').format(_formData.inspectionDate),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _formData.inspectionDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _formData.inspectionDate = date);
                  },
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateButton(
                  label: 'Time',
                  value: _formData.inspectionTime,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
                        final amPm = time.period == DayPeriod.am ? 'AM' : 'PM';
                        _formData.inspectionTime =
                            '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $amPm';
                      });
                    }
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }

  // ==================== STEP 2: CLIENT INFO ====================
  Widget _buildClientInfoStep(bool isDark) {
    final showErrors = _showErrorsForStep(1);
    final firstNameError = showErrors && _formData.firstName.trim().isEmpty;
    final lastNameError = showErrors && _formData.lastName.trim().isEmpty;
    final addressError = showErrors && _formData.address1.trim().isEmpty;
    final cityError = showErrors && _formData.city.trim().isEmpty;
    final stateError = showErrors && _formData.state.trim().isEmpty;
    final zipError = showErrors && _formData.zipCode.trim().isEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Client Name *', isDark),
        _buildCard(
          isDark: isDark,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration('First Name', isDark, hasError: firstNameError),
                  textCapitalization: TextCapitalization.words,
                  initialValue: _formData.firstName,
                  onChanged: (value) => setState(() => _formData.firstName = value),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: _inputDecoration('Last Name', isDark, hasError: lastNameError),
                  textCapitalization: TextCapitalization.words,
                  initialValue: _formData.lastName,
                  onChanged: (value) => setState(() => _formData.lastName = value),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Address *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              TextFormField(
                decoration: _inputDecoration('Street Address', isDark, hasError: addressError),
                textCapitalization: TextCapitalization.words,
                initialValue: _formData.address1,
                onChanged: (value) => setState(() => _formData.address1 = value),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: _inputDecoration('Address Line 2 (optional)', isDark),
                textCapitalization: TextCapitalization.words,
                initialValue: _formData.address2,
                onChanged: (value) => _formData.address2 = value,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      decoration: _inputDecoration('City', isDark, hasError: cityError),
                      textCapitalization: TextCapitalization.words,
                      initialValue: _formData.city,
                      onChanged: (value) => setState(() => _formData.city = value),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _formData.state.isEmpty ? null : _formData.state,
                      decoration: _inputDecoration('State', isDark, hasError: stateError),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('State')),
                        ...USStates.all.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (value) => setState(() => _formData.state = value ?? ''),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration('Zip', isDark, hasError: zipError),
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      initialValue: _formData.zipCode,
                      onChanged: (value) => setState(() => _formData.zipCode = value),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Contact Info', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              TextFormField(
                decoration: _inputDecoration('Phone Number', isDark),
                keyboardType: TextInputType.phone,
                initialValue: _formData.phone,
                onChanged: (value) => _formData.phone = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: _inputDecoration('Email Address', isDark),
                keyboardType: TextInputType.emailAddress,
                initialValue: _formData.email1,
                onChanged: (value) => _formData.email1 = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: _inputDecoration('Email Address 2 (optional)', isDark),
                keyboardType: TextInputType.emailAddress,
                initialValue: _formData.email2,
                onChanged: (value) => _formData.email2 = value,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Client Presence', isDark),
        _buildCard(
          isDark: isDark,
          child: SwitchListTile(
            title: const Text('Client On-Site?'),
            subtitle: Text(
              _formData.onSiteClient
                  ? 'Client is present during inspection'
                  : 'Client is not present',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
            ),
            value: _formData.onSiteClient,
            activeTrackColor: _accent.withValues(alpha: 0.5),
            activeThumbColor: _accent,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => _formData.onSiteClient = value),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Exterior Home Image', isDark),
        _buildImageCapture(
          image: _formData.exteriorHomeImage,
          fieldName: 'ext_h_img',
          label: 'Take photo of exterior home',
          onImageSelected: (img) => setState(() => _formData.exteriorHomeImage = img),
          isDark: isDark,
        ),
      ],
    );
  }

  // ==================== STEP 3: SYSTEM TYPE ====================
  Widget _buildSystemTypeStep(bool isDark) {
    final showErrors = _showErrorsForStep(2);
    final hasError = showErrors && _formData.systemType.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Select System Type *', isDark),
        if (hasError)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Please select a system type',
              style: TextStyle(color: _red, fontSize: 13),
            ),
          ),
        const SizedBox(height: 8),
        ...SystemTypes.all.map((type) {
          final isSelected = _formData.systemType == type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _formData.systemType = type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasError ? _red.withValues(alpha: 0.05) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _accent : (hasError ? _red : (isDark ? Colors.white12 : Colors.black12)),
                    width: isSelected ? 2 : (hasError ? 2 : 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSystemTypeIcon(type),
                      color: isSelected ? _accent : (isDark ? Colors.white54 : Colors.black54),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? _accent
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSystemTypeDescription(type),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: _accent, size: 24),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getSystemTypeIcon(String type) {
    switch (type) {
      case 'Electric':
        return Icons.electric_bolt;
      case 'Furnace':
        return Icons.local_fire_department;
      case 'Masonry Fireplace':
        return Icons.home;
      case 'Built-In Fireplace':
        return Icons.fireplace;
      case 'Wood Stove':
        return Icons.outdoor_grill;
      default:
        return Icons.question_mark;
    }
  }

  String _getSystemTypeDescription(String type) {
    switch (type) {
      case 'Electric':
        return 'Wall-mounted, insert, free-standing, or built-in electric fireplace';
      case 'Furnace':
        return 'Gas, oil, solid fuel, or wood burning furnace system';
      case 'Masonry Fireplace':
        return 'Traditional brick or stone fireplace with masonry chimney';
      case 'Built-In Fireplace':
        return 'Factory-built/prefab fireplace with metal chimney';
      case 'Wood Stove':
        return 'Free-standing or insert wood burning stove';
      default:
        return '';
    }
  }

  // ==================== STEP 4: SYSTEM DETAILS ====================
  Widget _buildSystemDetailsStep(bool isDark) {
    switch (_formData.systemType) {
      case 'Electric':
        return _buildElectricSystemFields(isDark);
      case 'Furnace':
        return _buildFurnaceSystemFields(isDark);
      case 'Masonry Fireplace':
        return _buildMasonryFireplaceFields(isDark);
      case 'Built-In Fireplace':
        return _buildBuiltInFireplaceFields(isDark);
      case 'Wood Stove':
        return _buildWoodStoveFields(isDark);
      default:
        return Center(child: Text('Unknown system type: ${_formData.systemType}'));
    }
  }

  // ==================== ELECTRIC SYSTEM FIELDS ====================
  Widget _buildElectricSystemFields(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Electric Fireplace System', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('System Working?'),
                value: _formData.electricSystemWorking ?? true,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                activeThumbColor: _accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _formData.electricSystemWorking = value),
              ),
              if (_formData.electricSystemWorking == false) ...[
                const Divider(),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _formData.electricSystemType,
                  decoration: _inputDecoration('Electric System Type', isDark),
                  items: ElectricSystemTypes.all
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.electricSystemType = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.electricStarterType,
                  decoration: _inputDecoration('Electric Starter Type', isDark),
                  items: ElectricStarterTypes.all
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.electricStarterType = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _formData.electricFireplaceCondition,
                  decoration: _inputDecoration('Fireplace Condition', isDark),
                  onChanged: (value) => _formData.electricFireplaceCondition = value,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _formData.electricFireplaceWidth,
                        decoration: _inputDecoration('Width', isDark),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _formData.electricFireplaceWidth = value,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _formData.electricFireplaceHeight,
                        decoration: _inputDecoration('Height', isDark),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _formData.electricFireplaceHeight = value,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Electric Fireplace Image', isDark),
        _buildImageCapture(
          image: _formData.electricFireplaceImage,
          fieldName: 'electric_fireplace_img',
          label: 'Take photo of electric fireplace',
          onImageSelected: (img) => setState(() => _formData.electricFireplaceImage = img),
          isDark: isDark,
        ),

        const SizedBox(height: 20),
        _buildInfoBox(
          isDark: isDark,
          icon: Icons.info_outline,
          text: 'All electric fireplaces are meeting all safety regulations and cannot put you in any potential fire hazards.',
          color: Colors.blue,
        ),
      ],
    );
  }

  // ==================== FURNACE SYSTEM FIELDS ====================
  Widget _buildFurnaceSystemFields(bool isDark) {
    final showErrors = _showErrorsForStep(3);
    final burningTypeError = showErrors && _formData.burningType == null;
    final visualInspectionError = showErrors && _formData.furnaceVisualInspection == null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Furnace Details', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _formData.burningType,
                decoration: _inputDecoration('Burning Type *', isDark, hasError: burningTypeError),
                items: BurningTypes.all
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) => setState(() => _formData.burningType = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData.furnaceBrand,
                decoration: _inputDecoration('Furnace Brand (optional)', isDark),
                onChanged: (value) => _formData.furnaceBrand = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData.furnaceModelNo,
                decoration: _inputDecoration('Model No. (optional)', isDark),
                onChanged: (value) => _formData.furnaceModelNo = value,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Visual Furnace Inspection *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              _buildConditionDropdown(
                value: _formData.furnaceVisualInspection,
                label: 'Visual Inspection *',
                onChanged: (value) => setState(() => _formData.furnaceVisualInspection = value),
                isDark: isDark,
                hasError: visualInspectionError,
              ),
              if (_formData.furnaceVisualInspection == ConditionOptions.doesNotMeet) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _formData.furnaceVisualInspectionExplanation,
                  decoration: _inputDecoration('Explanation', isDark),
                  maxLines: 2,
                  onChanged: (value) => _formData.furnaceVisualInspectionExplanation = value,
                ),
                const SizedBox(height: 12),
                _buildImageCapture(
                  image: _formData.furnaceVisualInspectionImage,
                  fieldName: 'furnace_visual_inspection_img',
                  label: 'Take photo',
                  onImageSelected: (img) =>
                      setState(() => _formData.furnaceVisualInspectionImage = img),
                  isDark: isDark,
                  compact: true,
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Please note that our furnace inspection is visual only!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _red,
                ),
              ),
            ],
          ),
        ),

        if (_formData.burningType != null && _formData.burningType != 'Pellet Burning') ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Furnace Clearance to Combustibles', isDark),
          _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                _buildConditionDropdown(
                  value: _formData.furnaceClearance,
                  label: 'Clearance Status',
                  onChanged: (value) => setState(() => _formData.furnaceClearance = value),
                  isDark: isDark,
                ),
                if (_formData.furnaceClearance == ConditionOptions.doesNotMeet) ...[
                  const SizedBox(height: 12),
                  _buildFailureWarning(
                    isDark: isDark,
                    code: _formData.burningType == 'Gas / Oil Burner'
                        ? 'CODE 603.5.3.1 GAS OR FUEL-OIL HEATERS'
                        : 'CODE 603.5.3.2 SOLID FUEL-BURNING HEATERS',
                    description: _formData.burningType == 'Gas / Oil Burner'
                        ? 'A minimum of 18 inches (457 mm) shall be maintained between gas or fuel-oil heat-producing appliances and combustible materials.'
                        : 'A minimum of 36 inches (914 mm) shall be maintained between solid fuel-burning appliances and combustible materials.',
                  ),
                  const SizedBox(height: 12),
                  _buildImageCapture(
                    image: _formData.furnaceClearanceImage,
                    fieldName: 'furnace_clearance_img',
                    label: 'Take photo',
                    onImageSelected: (img) =>
                        setState(() => _formData.furnaceClearanceImage = img),
                    isDark: isDark,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionHeader('Furnace Venting', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Vented'),
                      value: 'Vented',
                      groupValue: _formData.furnaceVenting,
                      activeColor: _accent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _formData.furnaceVenting = value),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Unvented'),
                      value: 'Unvented',
                      groupValue: _formData.furnaceVenting,
                      activeColor: _accent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _formData.furnaceVenting = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_formData.furnaceVenting == 'Vented') ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Furnace Piping', isDark),
          _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _formData.furnacePipingType,
                  decoration: _inputDecoration('Piping Type', isDark),
                  items: FurnacePipingTypes.all
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.furnacePipingType = value),
                ),
                const SizedBox(height: 12),
                _buildConditionDropdown(
                  value: _formData.pipeClearance,
                  label: 'Pipe Clearance to Combustibles',
                  onChanged: (value) => setState(() => _formData.pipeClearance = value),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _formData.furnacePipeCircumference,
                        decoration: _inputDecoration('Pipe Circumference', isDark),
                        onChanged: (value) => _formData.furnacePipeCircumference = value,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _formData.furnacePipeDiameter,
                        decoration: _inputDecoration('Pipe Diameter', isDark),
                        onChanged: (value) => _formData.furnacePipeDiameter = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.furnacePipesConnection,
                  decoration: _inputDecoration('Pipes Connection', isDark),
                  items: ConditionOptions.pipeConnection
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.furnacePipesConnection = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.furnacePipeSootCondition,
                  decoration: _inputDecoration('Soot Condition', isDark),
                  items: ConditionOptions.sootCondition
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _formData.furnacePipeSootCondition = value),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionHeader('Furnace Image', isDark),
        _buildImageCapture(
          image: _formData.furnaceImage,
          fieldName: 'furnace_img',
          label: 'Take photo of furnace',
          onImageSelected: (img) => setState(() => _formData.furnaceImage = img),
          isDark: isDark,
        ),
      ],
    );
  }

  // ==================== MASONRY FIREPLACE FIELDS ====================
  Widget _buildMasonryFireplaceFields(bool isDark) {
    final showErrors = _showErrorsForStep(3);
    final fireboxError = showErrors && _formData.fireboxCondition == null;
    final damperError = showErrors && _formData.damper == null;
    final smokeChamberError = showErrors && _formData.smokeChamber == null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Fireplace Dimensions', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.fireplaceWidth,
                      decoration: _inputDecoration('Width', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.fireplaceWidth = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.fireplaceHeight,
                      decoration: _inputDecoration('Height', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.fireplaceHeight = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.fireplaceDepth,
                      decoration: _inputDecoration('Depth', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.fireplaceDepth = value,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Hearth Extension', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.hearthExtensionFront,
                      decoration: _inputDecoration('Front Extension', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.hearthExtensionFront = value,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.hearthExtensionSide,
                      decoration: _inputDecoration('Side Extension', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.hearthExtensionSide = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Meets Regulation?'),
                subtitle: const Text('16" front, 8" side (or 20"/12" for 6+ sq ft)'),
                value: _formData.hearthExtensionRegulation ?? true,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                activeThumbColor: _accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) =>
                    setState(() => _formData.hearthExtensionRegulation = value),
              ),
              if (_formData.hearthExtensionRegulation == false)
                _buildFailureWarning(
                  isDark: isDark,
                  code: 'CODE R1001.10 HEARTH EXTENSION DIMENSIONS',
                  description:
                      'Hearth extensions shall extend not less than 16 inches in front and 8 inches beyond each side of the fireplace opening.',
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Fireplace Clearance to Combustibles', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.fireplaceClearanceToCombustibles,
            label: 'Clearance Status',
            onChanged: (value) =>
                setState(() => _formData.fireplaceClearanceToCombustibles = value),
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Firebox Condition *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              _buildConditionDropdown(
                value: _formData.fireboxCondition,
                label: 'Firebox Status *',
                onChanged: (value) => setState(() => _formData.fireboxCondition = value),
                isDark: isDark,
                hasError: fireboxError,
              ),
              if (_formData.fireboxCondition == ConditionOptions.doesNotMeet) ...[
                const SizedBox(height: 12),
                _buildMultiSelectChips(
                  label: 'Repair Needs',
                  options: FireboxRepairNeeds.all,
                  selected: _formData.fireboxRepairNeeds ?? [],
                  onChanged: (values) => setState(() => _formData.fireboxRepairNeeds = values),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildFailureImageCapture(
                  image: _formData.fireboxImage,
                  fieldName: 'firebox_failure',
                  label: 'Take photo of issue',
                  onImageSelected: (img) => setState(() => _formData.fireboxImage = img),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Ash Dump', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.ashDump,
            label: 'Ash Dump Status',
            onChanged: (value) => setState(() => _formData.ashDump = value),
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Gas Line', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              _buildConditionDropdown(
                value: _formData.gasLine,
                label: 'Gas Line Status',
                onChanged: (value) => setState(() => _formData.gasLine = value),
                isDark: isDark,
              ),
              if (_formData.gasLine == ConditionOptions.doesNotMeet) ...[
                const SizedBox(height: 12),
                _buildMultiSelectChips(
                  label: 'Repair Needs',
                  options: GasLineRepairNeeds.all,
                  selected: _formData.gasLineRepairNeeds ?? [],
                  onChanged: (values) => setState(() => _formData.gasLineRepairNeeds = values),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildFailureImageCapture(
                  image: _formData.gasLineImage,
                  fieldName: 'gasline_failure',
                  label: 'Take photo of issue',
                  onImageSelected: (img) => setState(() => _formData.gasLineImage = img),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Damper *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              _buildConditionDropdown(
                value: _formData.damper,
                label: 'Damper Status *',
                onChanged: (value) => setState(() => _formData.damper = value),
                isDark: isDark,
                hasError: damperError,
              ),
              if (_formData.damper == ConditionOptions.doesNotMeet) ...[
                const SizedBox(height: 12),
                _buildMultiSelectChips(
                  label: 'Repair Needs',
                  options: DamperRepairNeeds.all,
                  selected: _formData.damperRepairNeeds ?? [],
                  onChanged: (values) => setState(() => _formData.damperRepairNeeds = values),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildFailureImageCapture(
                  image: _formData.damperImage,
                  fieldName: 'damper_failure',
                  label: 'Take photo of issue',
                  onImageSelected: (img) => setState(() => _formData.damperImage = img),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Smoke Chamber *', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.smokeChamber,
            decoration: _inputDecoration('Smoke Chamber Status *', isDark, hasError: smokeChamberError),
            items: ConditionOptions.smokeChsmber
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _formData.smokeChamber = value),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Soot Condition', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.masonrySoot,
            decoration: _inputDecoration('Soot Condition', isDark),
            items: ConditionOptions.sootCondition
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _formData.masonrySoot = value),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Masonry Fireplace Image', isDark),
        _buildImageCapture(
          image: _formData.masonryFireplaceImage,
          fieldName: 'masonry_fireplace_img',
          label: 'Take photo of masonry fireplace',
          onImageSelected: (img) => setState(() => _formData.masonryFireplaceImage = img),
          isDark: isDark,
        ),
      ],
    );
  }

  // ==================== BUILT-IN FIREPLACE FIELDS ====================
  Widget _buildBuiltInFireplaceFields(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Built-In Fireplace Details', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.builtInWidth,
                      decoration: _inputDecoration('Width', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.builtInWidth = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.builtInHeight,
                      decoration: _inputDecoration('Height', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.builtInHeight = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _formData.builtInDepth,
                      decoration: _inputDecoration('Depth', isDark),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _formData.builtInDepth = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData.builtInModelNo,
                decoration: _inputDecoration('Model No.', isDark),
                onChanged: (value) => _formData.builtInModelNo = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _formData.builtInSerialNo,
                decoration: _inputDecoration('Serial No.', isDark),
                onChanged: (value) => _formData.builtInSerialNo = value,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Hearth Extensions', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.builtInHearth,
            label: 'Hearth Extensions Status',
            onChanged: (value) => setState(() => _formData.builtInHearth = value),
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Clearance to Combustibles', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.builtInClearance,
            label: 'Clearance Status',
            onChanged: (value) => setState(() => _formData.builtInClearance = value),
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Glass Door', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.glassDoorCondition,
            label: 'Glass Door Condition',
            onChanged: (value) => setState(() => _formData.glassDoorCondition = value),
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Gas Connection', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Gas Connection?'),
                value: _formData.builtInGasConnection ?? false,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                activeThumbColor: _accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _formData.builtInGasConnection = value),
              ),
              if (_formData.builtInGasConnection == true) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.gasFuelType,
                  decoration: _inputDecoration('Type of Fuel', isDark),
                  items: GasFuelTypes.all
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.gasFuelType = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.gasStarterType,
                  decoration: _inputDecoration('Gas Starter Type', isDark),
                  items: GasStarterTypes.all
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.gasStarterType = value),
                ),
                const SizedBox(height: 12),
                _buildConditionDropdown(
                  value: _formData.gasLineBurner,
                  label: 'Gas Line / Burner Condition',
                  onChanged: (value) => setState(() => _formData.gasLineBurner = value),
                  isDark: isDark,
                ),
                if (_formData.gasStarterType == 'Remote / Pilot Light Starter') ...[
                  const SizedBox(height: 12),
                  _buildConditionDropdown(
                    value: _formData.gasValveCondition,
                    label: 'Gas Valve Condition',
                    onChanged: (value) => setState(() => _formData.gasValveCondition = value),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildConditionDropdown(
                    value: _formData.pilotLightCondition,
                    label: 'Pilot Light Condition',
                    onChanged: (value) => setState(() => _formData.pilotLightCondition = value),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildConditionDropdown(
                    value: _formData.thermocoupleCondition,
                    label: 'Thermocouple Condition',
                    onChanged: (value) => setState(() => _formData.thermocoupleCondition = value),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _formData.remoteSystemCondition,
                    decoration: _inputDecoration('Remote System', isDark),
                    items: ConditionOptions.remoteSystem
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _formData.remoteSystemCondition = value),
                  ),
                ],
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Refractory Panels', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.refractoryPanelsCondition,
            decoration: _inputDecoration('Panels Condition', isDark),
            items: ConditionOptions.refractoryPanels
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _formData.refractoryPanelsCondition = value),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('System Venting', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('System Vented?'),
                value: _formData.systemVented ?? false,
                activeTrackColor: _accent.withValues(alpha: 0.5),
                activeThumbColor: _accent,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _formData.systemVented = value),
              ),
              if (_formData.systemVented == true) ...[
                const SizedBox(height: 12),
                _buildConditionDropdown(
                  value: _formData.builtInDamper,
                  label: 'Damper Status',
                  onChanged: (value) => setState(() => _formData.builtInDamper = value),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.builtInSoot,
                  decoration: _inputDecoration('Soot Condition', isDark),
                  items: ConditionOptions.sootCondition
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _formData.builtInSoot = value),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Built-In Fireplace Image', isDark),
        _buildImageCapture(
          image: _formData.builtInFireplaceImage,
          fieldName: 'buit_in_fireplace_img',
          label: 'Take photo of built-in fireplace',
          onImageSelected: (img) => setState(() => _formData.builtInFireplaceImage = img),
          isDark: isDark,
        ),
      ],
    );
  }

  // ==================== WOOD STOVE FIELDS ====================
  Widget _buildWoodStoveFields(bool isDark) {
    final showErrors = _showErrorsForStep(3);
    final stoveTypeError = showErrors && _formData.woodStoveType == null;
    final stoveConditionError = showErrors && _formData.stoveCondition == null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Wood Stove Type *', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.woodStoveType,
            decoration: _inputDecoration('Stove Type *', isDark, hasError: stoveTypeError),
            items: WoodStoveTypes.all
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (value) => setState(() => _formData.woodStoveType = value),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Stove Clearance to Combustibles', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              _buildConditionDropdown(
                value: _formData.stoveClearanceToCombustibles,
                label: 'Clearance Status',
                onChanged: (value) =>
                    setState(() => _formData.stoveClearanceToCombustibles = value),
                isDark: isDark,
              ),
              if (_formData.stoveClearanceToCombustibles == ConditionOptions.doesNotMeet) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _formData.stoveClearanceToCombustiblesExplanation,
                  decoration: _inputDecoration('Explanation', isDark),
                  maxLines: 2,
                  onChanged: (value) =>
                      _formData.stoveClearanceToCombustiblesExplanation = value,
                ),
                const SizedBox(height: 12),
                _buildFailureImageCapture(
                  image: _formData.stoveClearanceToCombustiblesImage,
                  fieldName: 'stove_clearance_failure',
                  label: 'Take photo of issue',
                  onImageSelected: (img) => setState(() => _formData.stoveClearanceToCombustiblesImage = img),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Stove Condition *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              _buildConditionDropdown(
                value: _formData.stoveCondition,
                label: 'Stove Condition *',
                onChanged: (value) => setState(() => _formData.stoveCondition = value),
                isDark: isDark,
                hasError: stoveConditionError,
              ),
              if (_formData.stoveCondition == ConditionOptions.doesNotMeet) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _formData.stoveConditionExplanation,
                  decoration: _inputDecoration('Explanation', isDark),
                  maxLines: 2,
                  onChanged: (value) => _formData.stoveConditionExplanation = value,
                ),
                const SizedBox(height: 12),
                _buildFailureImageCapture(
                  image: _formData.stoveConditionImage,
                  fieldName: 'stove_condition_failure',
                  label: 'Take photo of issue',
                  onImageSelected: (img) => setState(() => _formData.stoveConditionImage = img),
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),

        if (_formData.woodStoveType == 'Free Standing') ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Free Standing Pipes', isDark),
          _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _formData.freeStandingPipesCircumference,
                        decoration: _inputDecoration('Pipe Circumference', isDark),
                        onChanged: (value) => _formData.freeStandingPipesCircumference = value,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _formData.freeStandingPipesDiameter,
                        decoration: _inputDecoration('Pipe Diameter', isDark),
                        onChanged: (value) => _formData.freeStandingPipesDiameter = value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formData.freeStandingPipesConnection,
                  decoration: _inputDecoration('Pipes Connection', isDark),
                  items: ConditionOptions.pipeConnection
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _formData.freeStandingPipesConnection = value),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionHeader('Soot Condition', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.stoveSootCondition,
            decoration: _inputDecoration('Soot Condition', isDark),
            items: ConditionOptions.sootCondition
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _formData.stoveSootCondition = value),
          ),
        ),

        if (_formData.woodStoveType == 'Free Standing') ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Flue Ventilation', isDark),
          _buildCard(
            isDark: isDark,
            child: DropdownButtonFormField<String>(
              initialValue: _formData.flueVentilationType2,
              decoration: _inputDecoration('Ventilation Type', isDark),
              items: FlueVentilationTypes.woodStove
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (value) => setState(() => _formData.flueVentilationType2 = value),
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionHeader('Wood Stove Image', isDark),
        _buildImageCapture(
          image: _formData.woodStoveImage,
          fieldName: 'wood_stove_img',
          label: 'Take photo of wood stove',
          onImageSelected: (img) => setState(() => _formData.woodStoveImage = img),
          isDark: isDark,
        ),
      ],
    );
  }

  // ==================== STEP 5: CHIMNEY/FLUE ====================
  Widget _buildChimneyFlueStep(bool isDark) {
    // Skip for electric systems
    if (_formData.systemType == 'Electric') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: _accent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Electric systems do not require chimney/flue inspection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Continue to proceed',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final showErrors = _showErrorsForStep(4);
    // Cleanout Door error only applies when Masonry / Bricks is selected
    final cleanoutDoorError = showErrors &&
        _formData.flueVentilationType == 'Masonry / Bricks' &&
        _formData.cleanoutDoor == null;
    final chimneyLinerError = showErrors && _formData.chimneyLiner == null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Flue Ventilation Type', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.flueVentilationType,
            decoration: _inputDecoration('Ventilation Type', isDark),
            items: FlueVentilationTypes.all
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (value) => setState(() => _formData.flueVentilationType = value),
          ),
        ),

        if (_formData.flueVentilationType == 'Masonry / Bricks') ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Cleanout Door *', isDark),
          _buildCard(
            isDark: isDark,
            child: DropdownButtonFormField<String>(
              initialValue: _formData.cleanoutDoor,
              decoration: _inputDecoration('Cleanout Door Status *', isDark, hasError: cleanoutDoorError),
              items: ConditionOptions.cleanoutDoor
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _formData.cleanoutDoor = value),
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionHeader('Chimney Liner *', isDark),
        _buildCard(
          isDark: isDark,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _formData.chimneyLiner,
                decoration: _inputDecoration('Liner Condition *', isDark, hasError: chimneyLinerError),
                items: ConditionOptions.linerCondition
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => _formData.chimneyLiner = value),
              ),
              if (_formData.chimneyLiner == 'Does Not Meet Industry Standards') ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _formData.chimneyLinerExplanation,
                  decoration: _inputDecoration('Explanation', isDark),
                  maxLines: 2,
                  onChanged: (value) => _formData.chimneyLinerExplanation = value,
                ),
                const SizedBox(height: 12),
                _buildFailureWarning(
                  isDark: isDark,
                  code: 'CODE R1003.11 FLUE LINING (MATERIAL)',
                  description:
                      'All chimneys shall be lined. The lining material shall be appropriate for the type of appliance connected.',
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Chimney Liner Image', isDark),
        _buildImageCapture(
          image: _formData.chimneyLinerImage,
          fieldName: 'chimney_liner_img',
          label: 'Take photo of chimney liner',
          onImageSelected: (img) => setState(() => _formData.chimneyLinerImage = img),
          isDark: isDark,
        ),
      ],
    );
  }

  // ==================== STEP 6: EXTERIOR (Level 2+) ====================
  Widget _buildExteriorStep(bool isDark) {
    if (_formData.inspectionLevel == InspectionLevels.level1) {
      return Center(
        child: Text(
          'Exterior inspection is only for Level 2 and 3',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }

    // Skip for electric systems
    if (_formData.systemType == 'Electric') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: _accent, size: 64),
              SizedBox(height: 16),
              Text(
                'Electric systems do not require exterior chimney inspection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Exterior Chimney Type Image', isDark),
        _buildImageCapture(
          image: _formData.exteriorChimneyTypeImage,
          fieldName: 'exterior_chimney_type_img',
          label: 'Take photo of exterior chimney',
          onImageSelected: (img) => setState(() => _formData.exteriorChimneyTypeImage = img),
          isDark: isDark,
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Chimney Height From Roof Line', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.chimneyHeightFromRoofLine,
            label: 'Height Status',
            onChanged: (value) => setState(() => _formData.chimneyHeightFromRoofLine = value),
            isDark: isDark,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Chimney Cricket', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.chimneyCricket,
            decoration: _inputDecoration('Cricket Status', isDark),
            items: ConditionOptions.cricketCondition
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _formData.chimneyCricket = value),
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Flashing Condition', isDark),
        _buildCard(
          isDark: isDark,
          child: _buildConditionDropdown(
            value: _formData.flushingCondition,
            label: 'Flashing Status',
            onChanged: (value) => setState(() => _formData.flushingCondition = value),
            isDark: isDark,
          ),
        ),

        if (_formData.flueVentilationType == 'Masonry / Bricks' ||
            _formData.systemType == 'Masonry Fireplace') ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Masonry Work Condition', isDark),
          _buildCard(
            isDark: isDark,
            child: Column(
              children: [
                _buildConditionDropdown(
                  value: _formData.masonryWorkCondition,
                  label: 'Masonry Status',
                  onChanged: (value) => setState(() => _formData.masonryWorkCondition = value),
                  isDark: isDark,
                ),
                if (_formData.masonryWorkCondition == ConditionOptions.doesNotMeet) ...[
                  const SizedBox(height: 12),
                  _buildMultiSelectChips(
                    label: 'Issues Found',
                    options: MasonryWorkIssues.all,
                    selected: _formData.masonryWorkIssues ?? [],
                    onChanged: (values) =>
                        setState(() => _formData.masonryWorkIssues = values),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildFailureImageCapture(
                    image: _formData.masonryWorkImage,
                    fieldName: 'masonry_work_failure',
                    label: 'Take photo of issue',
                    onImageSelected: (img) => setState(() => _formData.masonryWorkImage = img),
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Chimney Crown', isDark),
          _buildCard(
            isDark: isDark,
            child: DropdownButtonFormField<String>(
              initialValue: _formData.chimneyCrownCondition,
              decoration: _inputDecoration('Crown Condition', isDark),
              items: ConditionOptions.crownCondition
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _formData.chimneyCrownCondition = value),
            ),
          ),

          const SizedBox(height: 20),
          _buildSectionHeader('Chimney Rain Cap', isDark),
          _buildCard(
            isDark: isDark,
            child: DropdownButtonFormField<String>(
              initialValue: _formData.chimneyRainCap,
              decoration: _inputDecoration('Cap Condition', isDark),
              items: ConditionOptions.capCondition
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _formData.chimneyRainCap = value),
            ),
          ),
        ],

        const SizedBox(height: 20),
        _buildSectionHeader('Spark Arrestor', isDark),
        _buildCard(
          isDark: isDark,
          child: DropdownButtonFormField<String>(
            initialValue: _formData.chimneySparkArrestor,
            decoration: _inputDecoration('Spark Arrestor Status', isDark),
            items: ConditionOptions.sparkArrestorCondition
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) => setState(() => _formData.chimneySparkArrestor = value),
          ),
        ),
      ],
    );
  }

  // ==================== STEP 7: NOTES & SIGN ====================
  Widget _buildNotesSignStep(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Inspector Note', isDark),
        _buildCard(
          isDark: isDark,
          child: TextFormField(
            initialValue: _formData.inspectorNote,
            decoration: _inputDecoration('Add notes for the client', isDark),
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) => _formData.inspectorNote = value,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Failed Items Summary', isDark),
        _buildCard(
          isDark: isDark,
          child: Builder(
            builder: (context) {
              final failedItems = getFailedItems(_formData);
              if (failedItems.isEmpty) {
                return const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('No failed items'),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: failedItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning, color: _red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.item,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                item.code,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        // Recommended Services / Invoice Items
        const SizedBox(height: 20),
        _buildSectionHeader('Recommended Services / Repairs', isDark),
        _buildCard(
          isDark: isDark,
          child: InvoiceItemsPicker(
            selection: _invoiceItems,
            onSelectionChanged: (selection) => setState(() {}),
            sectionLabel: 'Repair Estimate',
            locationCode: widget.workizLocationCode,
          ),
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Inspector Signature', isDark),
        _buildSignatureCapture(
          signature: _formData.inspectorSignature,
          fieldName: 'inspector_signature',
          label: 'Sign here',
          onSignatureSelected: (sig) => setState(() => _formData.inspectorSignature = sig),
          isDark: isDark,
        ),

        if (_formData.onSiteClient) ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Client Signature', isDark),
          _buildSignatureCapture(
            signature: _formData.clientSignature,
            fieldName: 'client_signature',
            label: 'Client signs here',
            onSignatureSelected: (sig) => setState(() => _formData.clientSignature = sig),
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  // ==================== HELPER WIDGETS ====================

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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark, {bool hasError = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: hasError ? const TextStyle(color: _red) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: hasError ? _red : (isDark ? Colors.white24 : Colors.black12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? _red : (isDark ? Colors.white24 : Colors.black12),
          width: hasError ? 2 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: hasError ? _red : _accent, width: 2),
      ),
      filled: true,
      fillColor: hasError
          ? _red.withValues(alpha: 0.05)
          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildDateButton({
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
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: _accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionDropdown({
    required String? value,
    required String label,
    required Function(String?) onChanged,
    required bool isDark,
    bool hasError = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _inputDecoration(label, isDark, hasError: hasError),
      items: ConditionOptions.standard
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required List<String> options,
    required List<String> selected,
    required Function(List<String>) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: _accent.withValues(alpha: 0.3),
              checkmarkColor: _accent,
              onSelected: (checked) {
                final newList = List<String>.from(selected);
                if (checked) {
                  newList.add(option);
                } else {
                  newList.remove(option);
                }
                onChanged(newList);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFailureWarning({
    required bool isDark,
    required String code,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: _red, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'INSPECTION FAILED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _red),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required bool isDark,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCapture({
    required InspectionImage? image,
    required String fieldName,
    required String label,
    required Function(InspectionImage) onImageSelected,
    required bool isDark,
    bool compact = false,
  }) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        children: [
          if (image != null && image.hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image.bytes != null
                  ? Image.memory(
                      image.bytes!,
                      height: compact ? 100 : 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: compact ? 100 : 200,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.image)),
                    ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(fieldName, onImageSelected),
              icon: Icon(image?.hasImage == true ? Icons.refresh : Icons.add_a_photo),
              label: Text(image?.hasImage == true ? 'Replace Photo' : label),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact image capture for failure/issue documentation
  Widget _buildFailureImageCapture({
    required InspectionImage? image,
    required String fieldName,
    required String label,
    required Function(InspectionImage) onImageSelected,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt, size: 18, color: _red),
              const SizedBox(width: 8),
              Text(
                'Photo Evidence (Recommended)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (image != null && image.hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  image.bytes != null
                      ? Image.memory(
                          image.bytes!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 120,
                          color: Colors.grey[300],
                          child: const Center(child: Icon(Icons.image)),
                        ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _pickImage(fieldName, onImageSelected),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(fieldName, onImageSelected),
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: Text(label, style: const TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: BorderSide(color: _red.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignatureCapture({
    required InspectionImage? signature,
    required String fieldName,
    required String label,
    required Function(InspectionImage) onSignatureSelected,
    required bool isDark,
  }) {
    return _buildCard(
      isDark: isDark,
      child: Column(
        children: [
          if (signature != null && signature.hasImage) ...[
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
              child: signature.bytes != null
                  ? Image.memory(signature.bytes!, fit: BoxFit.contain)
                  : const Center(child: Icon(Icons.draw)),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(fieldName, onSignatureSelected),
              icon: const Icon(Icons.draw),
              label: Text(signature?.hasImage == true ? 'Re-sign' : label),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(String fieldName, Function(InspectionImage) onSelected) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
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

    if (source == null) return;

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

      onSelected(InspectionImage(
        fieldName: fieldName,
        bytes: bytes,
        base64Data: base64Data,
        filename: image.name,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
