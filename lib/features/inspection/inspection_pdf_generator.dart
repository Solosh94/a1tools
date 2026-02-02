// Inspection PDF Generator
//
// Generates PDF inspection reports matching the A1 Chimney template.
// Based on the old system's format with professional layout.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'inspection_data.dart';
import '../inventory/invoice_items_service.dart';
import '../../widgets/captioned_image_picker.dart';
import '../admin/logo_service.dart';

class InspectionPdfGenerator {
  // Theme colors matching old system
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF000000); // Black
  static const PdfColor _secondaryColor = PdfColor.fromInt(0xFF333333); // Dark Gray
  static const PdfColor _successColor = PdfColor.fromInt(0xFF1e8449); // Dark Green
  static const PdfColor _errorColor = PdfColor.fromInt(0xFFc0392b); // Dark Red
  static const PdfColor _neutralColor = PdfColor.fromInt(0xFF5d6d7e); // Dark Blue Gray
  static const PdfColor _textPrimary = PdfColor.fromInt(0xFF000000);
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF333333);
  static const PdfColor _textLight = PdfColor.fromInt(0xFF5d6d7e);
  static const PdfColor _bgSecondary = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _bgHighlight = PdfColor.fromInt(0xFFF8F9FA);
  static const PdfColor _borderLight = PdfColor.fromInt(0xFFD9D9D9);
  static const PdfColor _warningBg = PdfColor.fromInt(0xFFFEF3C7);

  // Font sizes
  static const double _fontXs = 7;
  static const double _fontSm = 8;
  static const double _fontBase = 9;
  static const double _fontMd = 10;
  static const double _fontLg = 12;
  static const double _fontXxl = 22;

  // Spacing
  static const double _spacingXs = 2;
  static const double _spacingSm = 4;
  static const double _spacingMd = 8;
  static const double _spacingLg = 12;
  static const double _spacingXl = 16;

  static const double _footerHeight = 85;

  /// Generate PDF with optional invoice items and images
  static Future<Uint8List> generatePdf(
    InspectionFormData data, {
    InvoiceItemsSelection? invoiceItems,
    List<CaptionedImage>? images,
    String? workizJobSerial,
    String? workizJobId,
    String? technicianName,
    String? csiaNumber,
    String? companyName,
    String? companyPhone,
    String? companyEmail,
    String? companyWebsite,
    String? companyLicense,
    String? termsAndConditions,
  }) async {
    final pdf = pw.Document();

    // Load logos - use LogoService for company logo (supports custom logos)
    Uint8List? logoBytes;
    Uint8List? certLogoBytes;
    try {
      // Get company logo from LogoService (custom or default with fallback)
      logoBytes = await LogoService.getCompanyLogo();
    } catch (e) {
      // Logo not available, try fallback to asset directly
      try {
        final logoData = await rootBundle.load('assets/images/logo.png');
        logoBytes = logoData.buffer.asUint8List();
      } catch (e) {
        // Logo not available at all
        debugPrint('[InspectionPdfGenerator] Error: $e');
      }
    }
    try {
      final certData = await rootBundle.load('assets/images/csia_logo.png');
      certLogoBytes = certData.buffer.asUint8List();
    } catch (e) {
      // Cert logo not available
    }

    // Get inspection items with their statuses
    final inspectionItems = _getInspectionItems(data);
    final failedItems = inspectionItems.where((i) => i.status == 'fail').toList();
    final passedItems = inspectionItems.where((i) => i.status == 'pass').toList();
    final naItems = inspectionItems.where((i) => i.status == 'na').toList();
    final hasFailed = failedItems.isNotEmpty;

    // Format dates
    final inspectionDate = _formatDateLong(data.inspectionDate);
    final jobNumber = workizJobSerial ?? data.jobId ?? 'N/A';

    // Company info defaults
    final company = companyName ?? 'A1 Chimney';
    final phone = companyPhone ?? '(888) 984-4344';
    final email = companyEmail ?? 'info@a-1chimney.com';
    final terms = termsAndConditions ?? _defaultTermsAndConditions;

    // Collect all images from inspection
    final allImages = _collectAllImages(data, images);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.only(
          left: 34, right: 34, top: 20, bottom: _footerHeight,
        ),
        header: (context) => _buildHeader(
          logoBytes: logoBytes,
          certLogoBytes: certLogoBytes,
          jobNumber: jobNumber,
          inspectionDate: inspectionDate,
          timeSlot: data.inspectionTime,
          technicianName: technicianName ?? data.inspectorName,
          csiaNumber: csiaNumber,
          companyName: company,
        ),
        footer: (context) => _buildFooter(
          context: context,
          logoBytes: logoBytes,
          companyName: company,
          phone: phone,
          email: email,
        ),
        build: (context) => [
          // Title Section
          _buildTitleSection(jobNumber, inspectionDate, company),
          pw.SizedBox(height: _spacingLg),

          // Service Overview
          _buildServiceOverview(
            data: data,
            jobNumber: jobNumber,
            inspectionDate: inspectionDate,
            hasFailed: hasFailed,
            exteriorImage: data.exteriorHomeImage?.bytes,
          ),
          pw.SizedBox(height: _spacingMd),

          // System Details
          _buildSystemDetails(data, allImages),
          pw.SizedBox(height: _spacingXl),

          // Inspection Findings
          _buildInspectionFindings(inspectionItems, data),

          // Photo Gallery
          if (allImages.isNotEmpty) ...[
            pw.SizedBox(height: _spacingXl),
            _buildPhotoGallery(allImages),
          ],

          // Inspection Summary
          pw.SizedBox(height: _spacingXl),
          _buildInspectionSummary(
            items: inspectionItems,
            passedCount: passedItems.length,
            failedCount: failedItems.length,
            naCount: naItems.length,
          ),

          // Recommended Services / Estimate
          if (invoiceItems?.isNotEmpty == true) ...[
            pw.SizedBox(height: _spacingXl),
            _buildEstimateSection(invoiceItems!),
          ],

          // Terms and Conditions - Force page break to keep title with content
          pw.NewPage(),
          _buildTermsAndConditions(company, terms),

          // Signatures
          pw.SizedBox(height: _spacingXl),
          _buildSignaturesSection(data),
        ],
      ),
    );

    return pdf.save();
  }

  /// Build header with logo, job info, and certification badge
  static pw.Widget _buildHeader({
    Uint8List? logoBytes,
    Uint8List? certLogoBytes,
    required String jobNumber,
    required String inspectionDate,
    String? timeSlot,
    String? technicianName,
    String? csiaNumber,
    required String companyName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: _spacingMd),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borderLight, width: 1)),
      ),
      margin: const pw.EdgeInsets.only(bottom: 28),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Company Logo
          pw.Container(
            width: 120,
            child: logoBytes != null
                ? pw.Image(pw.MemoryImage(logoBytes), height: 35)
                : pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: _fontLg,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
          ),

          // Center: Job Info
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Job #: $jobNumber',
                      style: const pw.TextStyle(fontSize: _fontBase, color: _textSecondary),
                    ),
                    pw.Text(
                      '  |  ',
                      style: const pw.TextStyle(fontSize: _fontBase, color: _textSecondary),
                    ),
                    pw.Text(
                      'Date: $inspectionDate${timeSlot != null ? ", $timeSlot" : ""}',
                      style: const pw.TextStyle(fontSize: _fontBase, color: _textSecondary),
                    ),
                  ],
                ),
                if (technicianName != null && technicianName.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: _spacingXs),
                    child: pw.Text(
                      'Technician: $technicianName${csiaNumber != null ? " | CSIA #: $csiaNumber" : ""}',
                      style: const pw.TextStyle(fontSize: _fontBase, color: _textSecondary),
                    ),
                  ),
              ],
            ),
          ),

          // Right: Certification Badge
          pw.Container(
            width: 45,
            child: certLogoBytes != null
                ? pw.Image(pw.MemoryImage(certLogoBytes), height: 45)
                : pw.SizedBox(),
          ),
        ],
      ),
    );
  }

  /// Build footer with logo, contact info, NFPA warning, and page numbers
  static pw.Widget _buildFooter({
    required pw.Context context,
    Uint8List? logoBytes,
    required String companyName,
    required String phone,
    required String email,
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderLight, width: 1)),
      ),
      child: pw.Column(
        children: [
          // Top row: Logo, contact info, page number
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Logo
                pw.Container(
                  width: 100,
                  child: logoBytes != null
                      ? pw.Image(pw.MemoryImage(logoBytes), height: 20)
                      : pw.Text(
                          companyName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: _fontMd,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                ),
                // Contact info
                pw.Text(
                  '$phone | $email',
                  style: const pw.TextStyle(fontSize: _fontBase, color: _textLight),
                ),
                // Page number
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: _fontBase, color: _textLight),
                ),
              ],
            ),
          ),

          // Warning box
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            margin: const pw.EdgeInsets.symmetric(vertical: 2),
            decoration: pw.BoxDecoration(
              color: _warningBg,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                // Info icon
                pw.Container(
                  width: 12,
                  height: 12,
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF59E0B),
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'i',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    'NFPA 211 recommends getting your chimney cleaned and inspected once a year by a certified professional.',
                    style: const pw.TextStyle(fontSize: _fontBase, color: PdfColor.fromInt(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

          // Contact message
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Contact us today for annual maintenance program.',
              style: pw.TextStyle(
                fontSize: _fontBase,
                color: _textLight,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Build title section
  static pw.Widget _buildTitleSection(String jobNumber, String inspectionDate, String companyName) {
    return pw.Column(
      children: [
        pw.Text(
          'CHIMNEY INSPECTION REPORT',
          style: pw.TextStyle(
            fontSize: _fontXxl,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
            letterSpacing: 1,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: _spacingSm),
        pw.Text(
          'Job $jobNumber | $inspectionDate',
          style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: _spacingLg),

        // Welcome text box
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(_spacingLg),
          decoration: pw.BoxDecoration(
            color: _bgHighlight,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'Thank you for trusting $companyName with your chimney inspection needs. We\'re committed to ensuring the safety and efficiency of your system.\n\nOur detailed report below provides an assessment of your system\'s current condition, identifies any safety concerns, and offers professional recommendations for maintenance or repairs. If you have any questions about our findings, please don\'t hesitate to contact our office.',
            style: const pw.TextStyle(
              fontSize: _fontBase,
              color: _textSecondary,
              lineSpacing: 1.2,
            ),
            textAlign: pw.TextAlign.justify,
          ),
        ),
      ],
    );
  }

  /// Build service overview section
  static pw.Widget _buildServiceOverview({
    required InspectionFormData data,
    required String jobNumber,
    required String inspectionDate,
    required bool hasFailed,
    Uint8List? exteriorImage,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SERVICE OVERVIEW'),
        pw.Container(
          padding: const pw.EdgeInsets.all(_spacingLg),
          decoration: const pw.BoxDecoration(
            color: _bgSecondary,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Customer info - left side (70%)
              pw.Expanded(
                flex: 7,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Service Location (full width)
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: _spacingMd),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Service Location', style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary)),
                          pw.Text(
                            _formatAddress(data),
                            style: pw.TextStyle(fontSize: _fontBase, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Two column layout for other fields
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildOverviewField('Name', '${data.firstName} ${data.lastName}'),
                              _buildOverviewField('Inspection Result', hasFailed ? 'Fail' : 'Pass',
                                  valueColor: hasFailed ? _errorColor : _successColor,
                                  bold: true),
                              _buildOverviewField('Email', data.email1),
                              _buildOverviewField('Inspection Level', data.inspectionLevel),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildOverviewField('Job Number', jobNumber),
                              _buildOverviewField('Primary Phone', data.phone),
                              _buildOverviewField('Date & Time', '$inspectionDate | ${data.inspectionTime}'),
                              _buildOverviewField('Reason for Inspection', data.reasonForInspection.isNotEmpty ? data.reasonForInspection : 'Not Specified'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Exterior home image - right side (25%)
              pw.Container(
                width: 120,
                margin: const pw.EdgeInsets.only(left: _spacingMd),
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _borderLight),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: exteriorImage != null
                          ? pw.ClipRRect(
                              horizontalRadius: 4,
                              verticalRadius: 4,
                              child: pw.Image(
                                pw.MemoryImage(exteriorImage),
                                fit: pw.BoxFit.cover,
                              ),
                            )
                          : pw.Center(
                              child: pw.Text(
                                'No Image',
                                style: const pw.TextStyle(fontSize: _fontXs, color: _textLight),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                    ),
                    pw.SizedBox(height: _spacingXs),
                    pw.Text(
                      'Exterior Home Image',
                      style: const pw.TextStyle(fontSize: _fontXs, color: _textSecondary),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOverviewField(String label, String value, {PdfColor? valueColor, bool bold = false}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: _spacingSm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary)),
          pw.Text(
            value.isEmpty ? 'N/A' : value,
            style: pw.TextStyle(
              fontSize: _fontBase,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build system details section
  static pw.Widget _buildSystemDetails(InspectionFormData data, List<_GalleryImage> allImages) {
    final fields = _getSystemFields(data);

    // Get system image based on system type
    Uint8List? systemImage;
    if (data.systemType == 'Masonry Fireplace') {
      systemImage = data.masonryFireplaceImage?.bytes;
    } else if (data.systemType == 'Built-In Fireplace' || data.systemType == 'Gas Fireplace') {
      systemImage = data.builtInFireplaceImage?.bytes;
    } else if (data.systemType == 'Wood Stove') {
      systemImage = data.woodStoveImage?.bytes;
    } else if (data.systemType == 'Furnace') {
      systemImage = data.furnaceImage?.bytes;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SYSTEM DETAILS'),
        pw.Container(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // System info - left side
              pw.Expanded(
                flex: 7,
                child: pw.Column(
                  children: [
                    // Two fields per row
                    for (int i = 0; i < fields.length; i += 2)
                      pw.Container(
                        padding: const pw.EdgeInsets.only(bottom: _spacingSm),
                        margin: const pw.EdgeInsets.only(bottom: _spacingSm),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: _borderLight)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(child: _buildSystemField(fields[i].label, fields[i].value)),
                            if (i + 1 < fields.length)
                              pw.Expanded(child: _buildSystemField(fields[i + 1].label, fields[i + 1].value)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // System image - right side
              pw.Container(
                width: 120,
                margin: const pw.EdgeInsets.only(left: _spacingMd),
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: 100,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _borderLight),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: systemImage != null
                          ? pw.ClipRRect(
                              horizontalRadius: 4,
                              verticalRadius: 4,
                              child: pw.Image(
                                pw.MemoryImage(systemImage),
                                fit: pw.BoxFit.cover,
                              ),
                            )
                          : pw.Center(
                              child: pw.Text(
                                'No Image',
                                style: const pw.TextStyle(fontSize: _fontXs, color: _textLight),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                    ),
                    pw.SizedBox(height: _spacingXs),
                    pw.Text(
                      'System Image',
                      style: const pw.TextStyle(fontSize: _fontXs, color: _textSecondary),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSystemField(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary)),
        pw.SizedBox(height: 1),
        pw.Text(
          value.isEmpty ? 'N/A' : value,
          style: pw.TextStyle(fontSize: _fontBase, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  /// Build inspection findings section
  static pw.Widget _buildInspectionFindings(List<_InspectionItem> items, InspectionFormData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('INSPECTION FINDINGS'),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _borderLight),
          ),
          child: pw.Column(
            children: items.map((item) => _buildInspectionRow(item)).toList(),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInspectionRow(_InspectionItem item) {
    // Determine colors based on status
    PdfColor borderColor;
    PdfColor statusBgColor;
    PdfColor statusTextColor;
    String statusText;

    switch (item.status) {
      case 'pass':
        borderColor = _successColor;
        statusBgColor = _successColor;
        statusTextColor = PdfColors.white;
        statusText = 'PASS';
        break;
      case 'fail':
        borderColor = _errorColor;
        statusBgColor = _errorColor;
        statusTextColor = PdfColors.white;
        statusText = 'FAIL';
        break;
      default:
        borderColor = _neutralColor;
        statusBgColor = _neutralColor;
        statusTextColor = PdfColors.white;
        statusText = 'N/A';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(_spacingSm),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: borderColor, width: 3),
          bottom: const pw.BorderSide(color: _borderLight),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header row with title and status badge
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Text(
                      item.label,
                      style: pw.TextStyle(fontSize: _fontBase, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(width: _spacingMd),
                    if (item.resultText.isNotEmpty)
                      pw.Expanded(
                        child: pw.Text(
                          item.resultText,
                          style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: pw.BoxDecoration(
                  color: statusBgColor,
                ),
                child: pw.Text(
                  statusText,
                  style: pw.TextStyle(
                    fontSize: _fontSm,
                    fontWeight: pw.FontWeight.bold,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),

          // Issue details if failed
          if (item.status == 'fail' && item.issueCode != null) ...[
            pw.SizedBox(height: _spacingSm),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (item.repairNeeds != null)
                        pw.Text(
                          'Repair Needs\n${item.repairNeeds}',
                          style: const pw.TextStyle(fontSize: _fontSm),
                        ),
                      pw.SizedBox(height: _spacingXs),
                      pw.Text(
                        'Issue Code: ${item.issueCode}',
                        style: pw.TextStyle(fontSize: _fontSm, fontWeight: pw.FontWeight.bold, color: _textSecondary),
                      ),
                      if (item.issueDetails != null)
                        pw.Text(
                          item.issueDetails!,
                          style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary),
                        ),
                    ],
                  ),
                ),
                // Image for failed items
                if (item.imageBytes != null)
                  pw.Container(
                    width: 150,
                    margin: const pw.EdgeInsets.only(left: _spacingMd),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          height: 100,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _borderLight),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.ClipRRect(
                            horizontalRadius: 4,
                            verticalRadius: 4,
                            child: pw.Image(
                              pw.MemoryImage(item.imageBytes!),
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: _spacingXs),
                        pw.Text(
                          item.imageCaption ?? item.label,
                          style: const pw.TextStyle(fontSize: _fontXs, color: _textSecondary),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build photo gallery section
  static pw.Widget _buildPhotoGallery(List<_GalleryImage> images) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PHOTO GALLERY'),
        pw.Wrap(
          spacing: _spacingMd,
          runSpacing: _spacingMd,
          children: images.map((img) => _buildGalleryImage(img)).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildGalleryImage(_GalleryImage image) {
    return pw.Container(
      width: 250,
      child: pw.Column(
        children: [
          pw.Container(
            height: 180,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderLight),
            ),
            child: image.bytes != null
                ? pw.Image(pw.MemoryImage(image.bytes!), fit: pw.BoxFit.cover)
                : pw.Center(
                    child: pw.Text(
                      image.caption,
                      style: const pw.TextStyle(fontSize: _fontSm, color: _textLight),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
          ),
          pw.SizedBox(height: _spacingXs),
          pw.Text(
            image.caption,
            style: const pw.TextStyle(fontSize: _fontSm, color: _textSecondary),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build inspection summary table
  static pw.Widget _buildInspectionSummary({
    required List<_InspectionItem> items,
    required int passedCount,
    required int failedCount,
    required int naCount,
  }) {
    // Sort: Pass first, then N/A, then Fail
    final sortedItems = List<_InspectionItem>.from(items);
    sortedItems.sort((a, b) {
      final order = {'pass': 0, 'na': 1, 'fail': 2};
      return (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
    });

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('INSPECTION SUMMARY'),

        // Summary stats box
        pw.Container(
          padding: const pw.EdgeInsets.all(_spacingSm),
          margin: const pw.EdgeInsets.only(bottom: _spacingMd),
          decoration: const pw.BoxDecoration(
            color: _bgSecondary,
            border: pw.Border(left: pw.BorderSide(color: _secondaryColor, width: 3)),
          ),
          child: pw.Row(
            children: [
              pw.Text('Total: ', style: const pw.TextStyle(fontSize: _fontXs)),
              pw.Text('${items.length}', style: pw.TextStyle(fontSize: _fontXs, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: _spacingLg),
              pw.Text('Pass: ', style: const pw.TextStyle(fontSize: _fontXs, color: _successColor)),
              pw.Text('$passedCount', style: pw.TextStyle(fontSize: _fontXs, fontWeight: pw.FontWeight.bold, color: _successColor)),
              pw.SizedBox(width: _spacingLg),
              pw.Text('Fail: ', style: const pw.TextStyle(fontSize: _fontXs, color: _errorColor)),
              pw.Text('$failedCount', style: pw.TextStyle(fontSize: _fontXs, fontWeight: pw.FontWeight.bold, color: _errorColor)),
              pw.SizedBox(width: _spacingLg),
              pw.Text('N/A: ', style: const pw.TextStyle(fontSize: _fontXs, color: _neutralColor)),
              pw.Text('$naCount', style: pw.TextStyle(fontSize: _fontXs, fontWeight: pw.FontWeight.bold, color: _neutralColor)),
            ],
          ),
        ),

        // Summary table
        pw.Table(
          border: pw.TableBorder.all(color: _borderLight),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bgSecondary),
              children: [
                _tableHeaderCell('Item'),
                _tableHeaderCell('Status'),
                _tableHeaderCell('Notes'),
              ],
            ),
            // Rows
            ...sortedItems.asMap().entries.map((entry) {
              final item = entry.value;
              final isEven = entry.key % 2 == 0;
              return pw.TableRow(
                decoration: isEven ? pw.BoxDecoration(color: _bgHighlight.shade(0.2)) : null,
                children: [
                  _tableCell(item.label),
                  _tableStatusCell(item.status),
                  _tableCell(item.resultText),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: _fontBase, fontWeight: pw.FontWeight.bold, color: _secondaryColor),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: _fontSm),
      ),
    );
  }

  static pw.Widget _tableStatusCell(String status) {
    PdfColor color;
    String text;
    switch (status) {
      case 'pass':
        color = _successColor;
        text = 'PASS';
        break;
      case 'fail':
        color = _errorColor;
        text = 'FAIL';
        break;
      default:
        color = _neutralColor;
        text = 'N/A';
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: _fontSm, fontWeight: pw.FontWeight.bold, color: color),
      ),
    );
  }

  /// Build estimate/recommended services section
  static pw.Widget _buildEstimateSection(InvoiceItemsSelection invoiceItems) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('RECOMMENDED SERVICES'),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue300),
            color: const PdfColor.fromInt(0xFFE3F2FD),
          ),
          child: pw.Column(
            children: [
              // Items table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.blue200),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                    children: [
                      _estimateHeaderCell('Service / Item'),
                      _estimateHeaderCell('Qty', align: pw.TextAlign.center),
                      _estimateHeaderCell('Unit Price', align: pw.TextAlign.right),
                      _estimateHeaderCell('Total', align: pw.TextAlign.right),
                    ],
                  ),
                  // Items
                  ...invoiceItems.items.map((item) => pw.TableRow(
                    children: [
                      _estimateCell(item.item.name),
                      _estimateCell('${item.quantity}', align: pw.TextAlign.center),
                      _estimateCell(item.item.priceDisplay, align: pw.TextAlign.right),
                      _estimateCell(item.totalDisplay, align: pw.TextAlign.right),
                    ],
                  )),
                  // Total row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'TOTAL ESTIMATE',
                          style: pw.TextStyle(fontSize: _fontMd, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                      ),
                      pw.SizedBox(),
                      pw.SizedBox(),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          invoiceItems.totalDisplay,
                          style: pw.TextStyle(fontSize: _fontLg, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Disclaimer
              pw.Padding(
                padding: const pw.EdgeInsets.all(_spacingSm),
                child: pw.Text(
                  '* Prices are estimates and may vary based on actual conditions found during repair.',
                  style: const pw.TextStyle(fontSize: _fontSm, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _estimateHeaderCell(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: _fontBase, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        textAlign: align ?? pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _estimateCell(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: _fontMd, color: PdfColors.grey800),
        textAlign: align ?? pw.TextAlign.left,
      ),
    );
  }

  /// Build terms and conditions section
  static pw.Widget _buildTermsAndConditions(String companyName, String terms) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('$companyName TERMS AND CONDITIONS'),
        pw.Text(
          terms,
          style: const pw.TextStyle(fontSize: _fontBase, color: _textSecondary),
        ),
      ],
    );
  }

  /// Build signatures section
  static pw.Widget _buildSignaturesSection(InspectionFormData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: _spacingXl),
      child: pw.Row(
        children: [
          // Customer signature
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  'Customer Signature',
                  style: pw.TextStyle(
                    fontSize: _fontBase,
                    fontWeight: pw.FontWeight.bold,
                    color: _secondaryColor,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: _spacingSm),
                pw.Container(
                  height: 70,
                  width: 180,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _borderLight),
                  ),
                  child: data.clientSignature?.bytes != null
                      ? pw.Image(pw.MemoryImage(data.clientSignature!.bytes!), fit: pw.BoxFit.contain)
                      : data.onSiteClient
                          ? pw.Center(child: pw.Text('.', style: const pw.TextStyle(color: PdfColors.grey400)))
                          : pw.Center(
                              child: pw.Text(
                                'Customer was not present\nduring inspection',
                                style: const pw.TextStyle(fontSize: _fontSm, color: _textLight),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                ),
                pw.SizedBox(height: _spacingXs),
                pw.Text(
                  'Signed on: ${_formatDateShort(data.inspectionDate)}',
                  style: const pw.TextStyle(fontSize: _fontSm, color: _textPrimary),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          // Divider
          pw.Container(
            width: 1,
            height: 100,
            color: _borderLight,
            margin: const pw.EdgeInsets.symmetric(horizontal: _spacingXl),
          ),

          // Technician signature
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  'Technician Signature',
                  style: pw.TextStyle(
                    fontSize: _fontBase,
                    fontWeight: pw.FontWeight.bold,
                    color: _secondaryColor,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: _spacingSm),
                pw.Container(
                  height: 70,
                  width: 180,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _borderLight),
                  ),
                  child: data.inspectorSignature?.bytes != null
                      ? pw.Image(pw.MemoryImage(data.inspectorSignature!.bytes!), fit: pw.BoxFit.contain)
                      : pw.Center(child: pw.Text('(signature)', style: const pw.TextStyle(fontSize: _fontSm, color: _textLight))),
                ),
                pw.SizedBox(height: _spacingXs),
                pw.Text(
                  'Signed on: ${_formatDateShort(data.inspectionDate)}',
                  style: const pw.TextStyle(fontSize: _fontSm, color: _textPrimary),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build section title
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: _spacingXs),
      margin: const pw.EdgeInsets.only(bottom: _spacingMd),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borderLight)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: _fontLg,
          fontWeight: pw.FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

  // ============ Helper Methods ============

  static String _formatAddress(InspectionFormData data) {
    final parts = <String>[];
    if (data.address1.isNotEmpty) parts.add(data.address1);
    if (data.address2?.isNotEmpty == true) parts.add(data.address2!);
    final cityStateZip = <String>[];
    if (data.city.isNotEmpty) cityStateZip.add(data.city);
    if (data.state.isNotEmpty) cityStateZip.add(data.state);
    if (data.zipCode.isNotEmpty) cityStateZip.add(data.zipCode);
    if (cityStateZip.isNotEmpty) parts.add(cityStateZip.join(', '));
    return parts.join(', ');
  }

  static String _formatDateLong(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Get system-specific fields
  static List<_SystemField> _getSystemFields(InspectionFormData data) {
    final fields = <_SystemField>[
      _SystemField('System Type', data.systemType),
    ];

    switch (data.systemType) {
      case 'Masonry Fireplace':
        if (data.fireplaceWidth != null) fields.add(_SystemField('Width', '${data.fireplaceWidth} inches'));
        if (data.fireplaceHeight != null) fields.add(_SystemField('Height', '${data.fireplaceHeight} inches'));
        if (data.fireplaceDepth != null) fields.add(_SystemField('Depth', '${data.fireplaceDepth} inches'));
        fields.add(_SystemField('Fireplace Square Foot Dimensions', ''));
        break;
      case 'Built-In Fireplace':
        if (data.builtInWidth != null) fields.add(_SystemField('Width', '${data.builtInWidth} inches'));
        if (data.builtInHeight != null) fields.add(_SystemField('Height', '${data.builtInHeight} inches'));
        if (data.builtInDepth != null) fields.add(_SystemField('Depth', '${data.builtInDepth} inches'));
        if (data.builtInModelNo != null) fields.add(_SystemField('Model No.', data.builtInModelNo!));
        if (data.builtInSerialNo != null) fields.add(_SystemField('Serial No.', data.builtInSerialNo!));
        break;
      case 'Furnace':
        if (data.furnaceBrand != null) fields.add(_SystemField('Brand', data.furnaceBrand!));
        if (data.furnaceModelNo != null) fields.add(_SystemField('Model No.', data.furnaceModelNo!));
        if (data.burningType != null) fields.add(_SystemField('Burning Type', data.burningType!));
        break;
      case 'Wood Stove':
        if (data.woodStoveType != null) fields.add(_SystemField('Stove Type', data.woodStoveType!));
        break;
      case 'Electric':
        if (data.electricSystemType != null) fields.add(_SystemField('Electric Type', data.electricSystemType!));
        if (data.electricFireplaceWidth != null) fields.add(_SystemField('Width', '${data.electricFireplaceWidth} inches'));
        if (data.electricFireplaceHeight != null) fields.add(_SystemField('Height', '${data.electricFireplaceHeight} inches'));
        break;
    }

    return fields;
  }

  /// Get inspection items with their statuses
  static List<_InspectionItem> _getInspectionItems(InspectionFormData data) {
    final items = <_InspectionItem>[];

    // Helper to determine status
    String getStatus(String? value, {List<String> failValues = const []}) {
      if (value == null || value.isEmpty) {
        return 'na';
      }
      if (failValues.isNotEmpty && failValues.any((fv) => value.contains(fv))) {
        return 'fail';
      }
      if (value.contains('Does Not') || value.contains('Not Exist') ||
          value.contains('Heavy') || value.contains('Glazed') ||
          value.contains('Level 2') || value.contains('Level 3')) {
        return 'fail';
      }
      if (value.contains('N/A') || value.contains('not exist')) {
        return 'na';
      }
      return 'pass';
    }

    // System-specific inspection items
    switch (data.systemType) {
      case 'Masonry Fireplace':
        items.add(_InspectionItem(
          label: 'Clearance To Combustible',
          status: getStatus(data.fireplaceClearanceToCombustibles),
          resultText: data.fireplaceClearanceToCombustibles ?? '',
          imageBytes: data.fireplaceClearanceToCombustiblesImage?.bytes,
          imageCaption: 'Clearance To Combustible',
        ));
        items.add(_InspectionItem(
          label: 'Firebox Condition',
          status: getStatus(data.fireboxCondition),
          resultText: data.fireboxCondition ?? '',
          repairNeeds: data.fireboxCondition?.contains('Does Not') == true ? 'Damaged Masonry / Bricks, Mortar Gaps' : null,
          issueCode: data.fireboxCondition?.contains('Does Not') == true ? 'R1001.13 GAS LINES' : null,
          issueDetails: data.fireboxCondition?.contains('Does Not') == true
              ? 'Width of joints between firebricks shall not be greater than 1/4 inch (6.4 mm). firebricks shall not be greater than 1/4 inch (6.4 mm).'
              : null,
          imageBytes: data.fireboxImage?.bytes,
          imageCaption: 'Firebox Condition',
        ));
        items.add(_InspectionItem(
          label: 'Ash Dump',
          status: data.ashDump?.contains('not exist') == true ? 'na' : getStatus(data.ashDump),
          resultText: data.ashDump ?? '',
          imageBytes: data.ashDumpImage?.bytes,
          imageCaption: 'Ash Dump',
        ));
        items.add(_InspectionItem(
          label: 'Gas Line',
          status: getStatus(data.gasLine),
          resultText: data.gasLine ?? '',
          imageBytes: data.gasLineImage?.bytes,
          imageCaption: 'Gas Line',
        ));
        items.add(_InspectionItem(
          label: 'Damper',
          status: getStatus(data.damper),
          resultText: data.damper ?? '',
          imageBytes: data.damperImage?.bytes,
          imageCaption: 'Damper',
        ));
        items.add(_InspectionItem(
          label: 'Smoke Chamber',
          status: getStatus(data.smokeChamber, failValues: ['Does Not Parged']),
          resultText: data.smokeChamber ?? '',
          imageBytes: data.smokeChamberImage?.bytes,
          imageCaption: 'Smoke Chamber',
        ));
        items.add(_InspectionItem(
          label: 'Soot Condition',
          status: getStatus(data.masonrySoot, failValues: ['Level 2', 'Level 3', 'Heavy', 'Glazed']),
          resultText: data.masonrySoot ?? '',
          issueCode: data.masonrySoot?.contains('Level 2') == true ? 'NFPA 211' : null,
          issueDetails: data.masonrySoot?.contains('Level 2') == true
              ? 'The National Fire Protection Association (NFPA) Standard 211 requires that chimneys, fireplaces, and vents shall be inspected at least once a year for soundness, freedom from deposits, and correct clearances. Cleaning, maintenance, and repairs shall be done if necessary.'
              : null,
          imageBytes: data.masonrySootImage?.bytes,
          imageCaption: 'Soot Condition',
        ));
        break;

      case 'Built-In Fireplace':
        items.add(_InspectionItem(
          label: 'Hearth Extensions',
          status: getStatus(data.builtInHearth),
          resultText: data.builtInHearth ?? '',
        ));
        items.add(_InspectionItem(
          label: 'Clearance To Combustible',
          status: getStatus(data.builtInClearance),
          resultText: data.builtInClearance ?? '',
        ));
        items.add(_InspectionItem(
          label: 'Glass Door Condition',
          status: getStatus(data.glassDoorCondition),
          resultText: data.glassDoorCondition ?? '',
        ));
        if (data.builtInGasConnection == true) {
          if (data.gasFuelType != null && data.gasFuelType!.isNotEmpty) {
            items.add(_InspectionItem(label: 'Fuel Type', status: 'na', resultText: data.gasFuelType!));
          }
          items.add(_InspectionItem(label: 'Gas Line/Burner', status: getStatus(data.gasLineBurner), resultText: data.gasLineBurner ?? ''));
          items.add(_InspectionItem(label: 'Gas Valve', status: getStatus(data.gasValveCondition), resultText: data.gasValveCondition ?? ''));
          items.add(_InspectionItem(label: 'Pilot Light', status: getStatus(data.pilotLightCondition), resultText: data.pilotLightCondition ?? ''));
          items.add(_InspectionItem(label: 'Thermocouple', status: getStatus(data.thermocoupleCondition), resultText: data.thermocoupleCondition ?? ''));
        }
        if (data.systemVented == true) {
          items.add(_InspectionItem(label: 'Damper', status: getStatus(data.builtInDamper), resultText: data.builtInDamper ?? ''));
          items.add(_InspectionItem(label: 'Soot Condition', status: getStatus(data.builtInSoot, failValues: ['Heavy', 'Glazed']), resultText: data.builtInSoot ?? ''));
        }
        break;

      case 'Furnace':
        items.add(_InspectionItem(label: 'Visual Inspection', status: getStatus(data.furnaceVisualInspection), resultText: data.furnaceVisualInspection ?? ''));
        items.add(_InspectionItem(label: 'Clearance To Combustible', status: getStatus(data.furnaceClearance), resultText: data.furnaceClearance ?? ''));
        if (data.furnaceVenting == 'Vented') {
          items.add(_InspectionItem(label: 'Pipe Clearance', status: getStatus(data.pipeClearance), resultText: data.pipeClearance ?? ''));
          items.add(_InspectionItem(label: 'Pipes Connection', status: getStatus(data.furnacePipesConnection, failValues: ['Unsealed', 'Unconnected']), resultText: data.furnacePipesConnection ?? ''));
          items.add(_InspectionItem(label: 'Soot Condition', status: getStatus(data.furnacePipeSootCondition, failValues: ['Heavy', 'Glazed']), resultText: data.furnacePipeSootCondition ?? ''));
        }
        break;

      case 'Wood Stove':
        items.add(_InspectionItem(label: 'Clearance To Combustible', status: getStatus(data.stoveClearanceToCombustibles), resultText: data.stoveClearanceToCombustibles ?? ''));
        items.add(_InspectionItem(label: 'Stove Condition', status: getStatus(data.stoveCondition), resultText: data.stoveCondition ?? ''));
        if (data.woodStoveType == 'Free Standing') {
          items.add(_InspectionItem(label: 'Pipes Connection', status: getStatus(data.freeStandingPipesConnection), resultText: data.freeStandingPipesConnection ?? ''));
        }
        items.add(_InspectionItem(label: 'Soot Condition', status: getStatus(data.stoveSootCondition, failValues: ['Heavy', 'Glazed']), resultText: data.stoveSootCondition ?? ''));
        break;

      case 'Electric':
        items.add(_InspectionItem(
          label: 'Electric System',
          status: data.electricSystemWorking == true ? 'pass' : 'na',
          resultText: data.electricSystemWorking == true ? 'Working' : 'Not Working',
        ));
        break;
    }

    // Chimney/Flue items (non-electric)
    if (data.systemType != 'Electric') {
      items.add(_InspectionItem(
        label: 'Chimney Liner',
        status: getStatus(data.chimneyLiner, failValues: ['Does Not', 'Not Exist']),
        resultText: data.chimneyLiner ?? '',
        imageBytes: data.chimneyLinerImage?.bytes,
        imageCaption: 'Chimney Liner',
      ));
    }

    // Exterior items (Level 2+)
    if (data.inspectionLevel != InspectionLevels.level1 && data.systemType != 'Electric') {
      items.add(_InspectionItem(
        label: 'Chimney Height From Roof Line',
        status: getStatus(data.chimneyHeightFromRoofLine),
        resultText: data.chimneyHeightFromRoofLine ?? '',
        imageBytes: data.chimneyHeightFromRoofLineImage?.bytes,
        imageCaption: 'Chimney Height From Roof Line',
      ));
      items.add(_InspectionItem(
        label: 'Chimney Cricket',
        status: data.chimneyCricket?.contains('Does Not Need') == true ? 'na' : getStatus(data.chimneyCricket, failValues: ['Does Not', 'Needs Cricket']),
        resultText: data.chimneyCricket ?? '',
        imageBytes: data.chimneyCricketImage?.bytes,
        imageCaption: 'Chimney Cricket',
      ));
      items.add(_InspectionItem(
        label: 'Flashing Condition',
        status: getStatus(data.flushingCondition),
        resultText: data.flushingCondition ?? '',
        imageBytes: data.flushingConditionImage?.bytes,
        imageCaption: 'Flashing Condition',
      ));
      items.add(_InspectionItem(
        label: 'Masonry Work Condition',
        status: getStatus(data.masonryWorkCondition),
        resultText: data.masonryWorkCondition ?? '',
        imageBytes: data.masonryWorkImage?.bytes,
        imageCaption: 'Masonry Work Condition',
      ));
      items.add(_InspectionItem(
        label: 'Chimney Crown Condition',
        status: getStatus(data.chimneyCrownCondition, failValues: ['Does Not']),
        resultText: data.chimneyCrownCondition ?? '',
        issueCode: data.chimneyCrownCondition?.contains('Does Not') == true ? 'R1003.9.1 CHIMNEY CAP/CROWN' : null,
        issueDetails: data.chimneyCrownCondition?.contains('Does Not') == true
            ? 'Refer to IRC R1003.9.1 for specific requirements regarding chimney crowns. Ensure all construction and installation practices comply with these guidelines.'
            : null,
        imageBytes: data.chimneyCrownImage?.bytes,
        imageCaption: 'Chimney Crown Condition',
      ));
      items.add(_InspectionItem(
        label: 'Chimney Rain Cap',
        status: getStatus(data.chimneyRainCap, failValues: ['Does Not', 'Not Exist']),
        resultText: data.chimneyRainCap ?? '',
        imageBytes: data.chimneyRainCapImage?.bytes,
        imageCaption: 'Chimney Rain Cap',
      ));
    }

    return items;
  }

  /// Collect all images from inspection data
  static List<_GalleryImage> _collectAllImages(InspectionFormData data, List<CaptionedImage>? additionalImages) {
    final images = <_GalleryImage>[];

    // Helper to add an image
    void addImage(Uint8List? bytes, String caption) {
      if (bytes != null) {
        images.add(_GalleryImage(caption: caption, bytes: bytes));
      }
    }

    // Exterior home image
    addImage(data.exteriorHomeImage?.bytes, 'Exterior Home');

    // System-specific images
    switch (data.systemType) {
      case 'Masonry Fireplace':
        addImage(data.masonryFireplaceImage?.bytes, 'Masonry Fireplace');
        addImage(data.fireplaceClearanceToCombustiblesImage?.bytes, 'Clearance To Combustible');
        addImage(data.fireboxImage?.bytes, 'Firebox Condition');
        addImage(data.ashDumpImage?.bytes, 'Ash Dump');
        addImage(data.gasLineImage?.bytes, 'Gas Line');
        addImage(data.damperImage?.bytes, 'Damper');
        addImage(data.smokeChamberImage?.bytes, 'Smoke Chamber');
        addImage(data.masonrySootImage?.bytes, 'Soot Condition');
        break;
      case 'Built-In Fireplace':
        addImage(data.builtInFireplaceImage?.bytes, 'Built-In Fireplace');
        addImage(data.fireplaceModelImage?.bytes, 'Model Image');
        addImage(data.builtInHearthImage?.bytes, 'Hearth Extensions');
        addImage(data.builtInClearanceImage?.bytes, 'Clearance');
        addImage(data.glassDoorConditionImage?.bytes, 'Glass Door');
        addImage(data.gasLineBurnerImage?.bytes, 'Gas Line/Burner');
        addImage(data.builtInDamperImage?.bytes, 'Damper');
        addImage(data.builtInSootImage?.bytes, 'Soot Condition');
        break;
      case 'Furnace':
        addImage(data.furnaceImage?.bytes, 'Furnace');
        addImage(data.furnaceVisualInspectionImage?.bytes, 'Visual Inspection');
        addImage(data.furnaceClearanceImage?.bytes, 'Clearance');
        addImage(data.pipeClearanceImage?.bytes, 'Pipe Clearance');
        addImage(data.furnacePipesConnectionImage?.bytes, 'Pipes Connection');
        addImage(data.furnacePipeSootConditionImage?.bytes, 'Soot Condition');
        break;
      case 'Wood Stove':
        addImage(data.woodStoveImage?.bytes, 'Wood Stove');
        addImage(data.stoveClearanceToCombustiblesImage?.bytes, 'Clearance');
        addImage(data.stoveConditionImage?.bytes, 'Stove Condition');
        addImage(data.freeStandingPipesConnectionImage?.bytes, 'Pipes Connection');
        addImage(data.stoveSootConditionImage?.bytes, 'Soot Condition');
        break;
      case 'Electric':
        addImage(data.electricFireplaceImage?.bytes, 'Electric Fireplace');
        break;
    }

    // Chimney/Flue images
    addImage(data.chimneyLinerImage?.bytes, 'Chimney Liner');
    addImage(data.cleanoutDoorImage?.bytes, 'Cleanout Door');

    // Exterior images (Level 2+)
    addImage(data.exteriorChimneyTypeImage?.bytes, 'Exterior Chimney');
    addImage(data.chimneyHeightFromRoofLineImage?.bytes, 'Chimney Height From Roof');
    addImage(data.chimneyCricketImage?.bytes, 'Chimney Cricket');
    addImage(data.flushingConditionImage?.bytes, 'Flashing Condition');
    addImage(data.chimneySidingCoverConditionImage?.bytes, 'Siding Cover');
    addImage(data.chaseCoveringConditionImage?.bytes, 'Chase Covering');
    addImage(data.exteriorPipeConditionImage?.bytes, 'Exterior Pipe');
    addImage(data.masonryWorkImage?.bytes, 'Masonry Work');
    addImage(data.chimneyCrownImage?.bytes, 'Chimney Crown');
    addImage(data.chimneyRainCapImage?.bytes, 'Chimney Rain Cap');
    addImage(data.chimneySparkArrestorImage?.bytes, 'Spark Arrestor');

    // Add any additional images provided
    if (additionalImages != null) {
      for (final img in additionalImages) {
        if (img.hasImage && img.bytes != null) {
          images.add(_GalleryImage(caption: img.caption.isNotEmpty ? img.caption : img.fieldName, bytes: img.bytes));
        }
      }
    }

    return images;
  }

  // ============ Public API Methods ============

  /// Generate and share PDF
  static Future<void> generateAndShare(
    InspectionFormData data, {
    InvoiceItemsSelection? invoiceItems,
    List<CaptionedImage>? images,
    String? workizJobSerial,
  }) async {
    final pdfBytes = await generatePdf(data, invoiceItems: invoiceItems, images: images, workizJobSerial: workizJobSerial);
    final dir = await getTemporaryDirectory();
    final fileName = 'Inspection_${data.firstName}_${data.lastName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], subject: 'Chimney Inspection Report - ${data.firstName} ${data.lastName}');
  }

  /// Generate and print PDF
  static Future<void> generateAndPrint(
    InspectionFormData data, {
    InvoiceItemsSelection? invoiceItems,
    List<CaptionedImage>? images,
    String? workizJobSerial,
  }) async {
    final pdfBytes = await generatePdf(data, invoiceItems: invoiceItems, images: images, workizJobSerial: workizJobSerial);
    await Printing.sharePdf(bytes: pdfBytes, filename: 'Inspection_${data.firstName}_${data.lastName}.pdf');
  }

  /// Direct print PDF
  static Future<void> directPrint(
    InspectionFormData data, {
    InvoiceItemsSelection? invoiceItems,
    List<CaptionedImage>? images,
    String? workizJobSerial,
  }) async {
    final pdfBytes = await generatePdf(data, invoiceItems: invoiceItems, images: images, workizJobSerial: workizJobSerial);
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: 'Inspection_${data.firstName}_${data.lastName}');
  }

  /// Generate and save PDF
  static Future<String?> generateAndSave(
    InspectionFormData data, {
    InvoiceItemsSelection? invoiceItems,
    List<CaptionedImage>? images,
    String? workizJobSerial,
  }) async {
    final pdfBytes = await generatePdf(data, invoiceItems: invoiceItems, images: images, workizJobSerial: workizJobSerial);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'Inspection_${data.firstName}_${data.lastName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file.path;
  }

  /// Generate PDF bytes for upload
  static Future<Uint8List> generatePdfBytes(
    InspectionFormData data, {
    InvoiceItemsSelection? invoiceItems,
    List<CaptionedImage>? images,
    String? workizJobSerial,
  }) async {
    return generatePdf(data, invoiceItems: invoiceItems, images: images, workizJobSerial: workizJobSerial);
  }

  // Default terms and conditions
  static const String _defaultTermsAndConditions = '''1. Introduction
These terms and conditions "Terms" govern the use of the inspection report "Report" provided by the Company. By accepting and using the Report, the client "Client", "you", or "your" agrees to be bound by these Terms.

2. Scope of the Report
2.1 The Report is prepared based on a visual inspection of the accessible areas and systems of the chimney on the date of the inspection.
2.2 The Report is intended to provide an overview of the condition of the chimney and is not an exhaustive list of every potential issue or defect.
2.3 The Report is not a warranty or guarantee of any kind regarding the condition of the chimney.

3. Limitations and Exclusions
3.1 The inspection and the Report are limited to the visible and accessible areas of the chimney.
3.2 The inspection does not cover areas that require dismantling of components or specialized equipment.
3.3 The Report does not include an evaluation of environmental hazards unless specifically documented.

4. Client Responsibilities
4.1 The Client is responsible for providing accurate information regarding the chimney.
4.2 The Client must ensure safe and unobstructed access to the chimney.

5. Limitation of Liability
5.1 The Company's total liability is limited to the amount paid for the inspection services.
5.2 The Company is not liable for any indirect, incidental, special, or consequential damages.

6. Acceptance of Terms
By accepting and using the Report, the Client acknowledges that they have read, understood, and agreed to be bound by these Terms.''';
}

// ============ Helper Classes ============

class _SystemField {
  final String label;
  final String value;
  _SystemField(this.label, this.value);
}

class _InspectionItem {
  final String label;
  final String status; // 'pass', 'fail', 'na'
  final String resultText;
  final String? repairNeeds;
  final String? issueCode;
  final String? issueDetails;
  final Uint8List? imageBytes;
  final String? imageCaption;

  _InspectionItem({
    required this.label,
    required this.status,
    required this.resultText,
    this.repairNeeds,
    this.issueCode,
    this.issueDetails,
    this.imageBytes,
    this.imageCaption,
  });
}

class _GalleryImage {
  final String caption;
  final Uint8List? bytes;
  _GalleryImage({required this.caption, this.bytes});
}
