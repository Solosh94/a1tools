// Inspection Report Detail Screen
//
// Displays the full details of a comprehensive inspection report.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../app_theme.dart';
import '../../config/api_config.dart';
import 'inspection_report_service.dart';

class InspectionReportDetailScreen extends StatefulWidget {
 final int reportId;
 final bool isAdmin;
 final VoidCallback? onDeleted;
 final String? currentUsername; // For app messages sharing
 final String? currentRole; // For app messages sharing

 const InspectionReportDetailScreen({
 super.key,
 required this.reportId,
 this.isAdmin = false,
 this.onDeleted,
 this.currentUsername,
 this.currentRole,
 });

 @override
 State<InspectionReportDetailScreen> createState() =>
 _InspectionReportDetailScreenState();
}

class _InspectionReportDetailScreenState
 extends State<InspectionReportDetailScreen> {
 static const Color _accent = AppColors.accent;

 InspectionReportDetail? _report;
 bool _loading = true;
 String? _error;

 @override
 void initState() {
 super.initState();
 _loadReport();
 }

 /// Get the share position origin for iOS share sheet
 Rect? _getSharePositionOrigin() {
 final box = context.findRenderObject() as RenderBox?;
 if (box != null) {
 return box.localToGlobal(Offset.zero) & box.size;
 }
 return null;
 }

 Future<void> _loadReport() async {
 setState(() {
 _loading = true;
 _error = null;
 });

 try {
 final report =
 await InspectionReportService.instance.getReport(widget.reportId);
 if (mounted) {
 setState(() {
 _report = report;
 _loading = false;
 if (report == null) {
 _error = 'Report not found';
 }
 });
 }
 } catch (e) {
 if (mounted) {
 setState(() {
 _error = 'Failed to load report: $e';
 _loading = false;
 });
 }
 }
 }

 Future<void> _deleteReport() async {
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Delete Report'),
 content: const Text(
 'Are you sure you want to delete this inspection report? This action cannot be undone.'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Cancel'),
 ),
 TextButton(
 onPressed: () => Navigator.pop(ctx, true),
 style: TextButton.styleFrom(foregroundColor: Colors.red),
 child: const Text('Delete'),
 ),
 ],
 ),
 );

 if (confirm == true) {
 final success =
 await InspectionReportService.instance.deleteReport(widget.reportId);
 if (success && mounted) {
 widget.onDeleted?.call();
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Report deleted')),
 );
 } else if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Failed to delete report'),
 backgroundColor: Colors.red,
 ),
 );
 }
 }
 }

 void _showShareOptions() {
 final isDark = Theme.of(context).brightness == Brightness.dark;

 showModalBottomSheet(
 context: context,
 backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
 shape: const RoundedRectangleBorder(
 borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
 ),
 builder: (ctx) => SafeArea(
 child: Padding(
 padding: const EdgeInsets.symmetric(vertical: 16),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Container(
 width: 40,
 height: 4,
 decoration: BoxDecoration(
 color: isDark ? Colors.white24 : Colors.black26,
 borderRadius: BorderRadius.circular(2),
 ),
 ),
 const SizedBox(height: 16),
 Text(
 'Share Report',
 style: TextStyle(
 fontSize: 18,
 fontWeight: FontWeight.bold,
 color: isDark ? Colors.white : Colors.black,
 ),
 ),
 const SizedBox(height: 16),
 _buildShareOption(
 ctx,
 icon: Icons.picture_as_pdf,
 label: 'Save as PDF',
 color: Colors.red,
 onTap: () {
 Navigator.pop(ctx);
 _savePdf();
 },
 ),
 _buildShareOption(
 ctx,
 icon: Icons.email,
 label: 'Share via Email',
 color: Colors.blue,
 onTap: () {
 Navigator.pop(ctx);
 _shareViaEmail();
 },
 ),
 _buildShareOption(
 ctx,
 icon: Icons.chat,
 label: 'Share via WhatsApp',
 color: Colors.green,
 onTap: () {
 Navigator.pop(ctx);
 _shareViaWhatsApp();
 },
 ),
 _buildShareOption(
 ctx,
 icon: Icons.message,
 label: 'Share via Messages',
 color: Colors.orange,
 onTap: () {
 Navigator.pop(ctx);
 _shareViaMessages();
 },
 ),
 _buildShareOption(
 ctx,
 icon: Icons.share,
 label: 'Share via App Messages',
 color: _accent,
 onTap: () {
 Navigator.pop(ctx);
 _shareViaAppMessages();
 },
 ),
 _buildShareOption(
 ctx,
 icon: Icons.more_horiz,
 label: 'More Options...',
 color: Colors.grey,
 onTap: () {
 Navigator.pop(ctx);
 _shareGeneric();
 },
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildShareOption(
 BuildContext ctx, {
 required IconData icon,
 required String label,
 required Color color,
 required VoidCallback onTap,
 }) {
 final isDark = Theme.of(context).brightness == Brightness.dark;
 return ListTile(
 leading: Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(icon, color: color),
 ),
 title: Text(
 label,
 style: TextStyle(color: isDark ? Colors.white : Colors.black),
 ),
 onTap: onTap,
 );
 }

 Future<void> _printReport() async {
 if (_report == null) return;

 _showLoadingDialog('Preparing report for printing...');

 try {
 final pdfData = await _generatePdf();
 if (!mounted) return;
 Navigator.pop(context); // Close loading dialog

 await Printing.layoutPdf(
 onLayout: (format) async => pdfData,
 name: 'Inspection_Report_${_report!.id}',
 );
 } catch (e) {
 if (mounted) {
 Navigator.pop(context); // Close loading dialog
 _showError('Failed to print: $e');
 }
 }
 }

 Future<void> _savePdf() async {
 if (_report == null) return;

 _showLoadingDialog('Generating PDF...');

 try {
 final pdfData = await _generatePdf();
 if (!mounted) return;

 // Get save location
 final directory = await getApplicationDocumentsDirectory();
 final fileName = 'Inspection_Report_${_report!.id}_${DateFormat('yyyyMMdd').format(_report!.inspectionDate)}.pdf';
 final file = File('${directory.path}/$fileName');
 await file.writeAsBytes(pdfData);

 if (!mounted) return;
 Navigator.pop(context); // Close loading dialog

 // Offer to share the saved file
 final share = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('PDF Saved'),
 content: Text('Report saved to:\n${file.path}\n\nWould you like to share it?'),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx, false),
 child: const Text('Close'),
 ),
 TextButton(
 onPressed: () => Navigator.pop(ctx, true),
 child: const Text('Share'),
 ),
 ],
 ),
 );

 if (share == true && mounted) {
 await Share.shareXFiles(
 [XFile(file.path)],
 subject: 'Inspection Report',
 sharePositionOrigin: _getSharePositionOrigin(),
 );
 }
 } catch (e) {
 if (mounted) {
 Navigator.pop(context); // Close loading dialog
 _showError('Failed to save PDF: $e');
 }
 }
 }

 Future<void> _shareViaEmail() async {
 if (_report == null) return;

 _showLoadingDialog('Preparing report...');

 try {
 final pdfFile = await _savePdfToTemp();
 if (!mounted) return;
 Navigator.pop(context);

 final subject = 'Inspection Report - ${_report!.clientName}';
 final body = _getShareBody();

 await Share.shareXFiles(
 [XFile(pdfFile.path)],
 subject: subject,
 text: body,
 sharePositionOrigin: _getSharePositionOrigin(),
 );
 } catch (e) {
 if (mounted) {
 Navigator.pop(context);
 _showError('Failed to share: $e');
 }
 }
 }

 Future<void> _shareViaWhatsApp() async {
 if (_report == null) return;

 _showLoadingDialog('Preparing report...');

 try {
 final pdfFile = await _savePdfToTemp();
 if (!mounted) return;
 Navigator.pop(context);

 final text = _getShareBody();

 // On Windows, save file to Downloads folder and open Explorer with file selected for easy drag-drop
 if (Platform.isWindows) {
 // Save to Downloads folder for easier attachment
 final downloadsDir = Directory('${Platform.environment['USERPROFILE']}\\Downloads');
 final fileName = 'Inspection_Report_${_report!.clientName.replaceAll(RegExp(r'[^\w\s]'), '')}_${_report!.id}.pdf';
 final savedFile = File('${downloadsDir.path}\\$fileName');
 await savedFile.writeAsBytes(await pdfFile.readAsBytes());

 // Copy file path to clipboard for easy pasting
 await Clipboard.setData(ClipboardData(text: savedFile.path));

 // Open Explorer with the file selected (so user can drag-drop to WhatsApp)
 await Process.run('explorer.exe', ['/select,', savedFile.path]);

 // Also try to open WhatsApp with text
 final whatsappUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');

 if (await canLaunchUrl(whatsappUrl)) {
 await launchUrl(whatsappUrl);
 } else {
 // WhatsApp not installed, fall back to web.whatsapp.com
 final webWhatsApp = Uri.parse('https://web.whatsapp.com/send?text=${Uri.encodeComponent(text)}');
 await launchUrl(webWhatsApp, mode: LaunchMode.externalApplication);
 }

 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text(
 'WhatsApp opened! Drag the PDF from Explorer into WhatsApp to attach it.\n'
 '(File path also copied to clipboard)',
 ),
 backgroundColor: Colors.green,
 duration: Duration(seconds: 8),
 ),
 );
 }
 } else {
 // On mobile platforms, use the standard share which supports file attachments
 await Share.shareXFiles(
 [XFile(pdfFile.path)],
 text: text,
 sharePositionOrigin: _getSharePositionOrigin(),
 );
 }
 } catch (e) {
 if (mounted) {
 Navigator.pop(context);
 _showError('Failed to share: $e');
 }
 }
 }

 Future<void> _shareViaMessages() async {
 if (_report == null) return;

 _showLoadingDialog('Preparing report...');

 try {
 final pdfFile = await _savePdfToTemp();
 if (!mounted) return;
 Navigator.pop(context);

 await Share.shareXFiles(
 [XFile(pdfFile.path)],
 text: _getShareBody(),
 sharePositionOrigin: _getSharePositionOrigin(),
 );
 } catch (e) {
 if (mounted) {
 Navigator.pop(context);
 _showError('Failed to share: $e');
 }
 }
 }

 Future<void> _shareViaAppMessages() async {
 if (_report == null) return;

 // Check if we have the required username
 if (widget.currentUsername == null) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(
 content: Text('Unable to send via App Messages. Please try again from the main screen.'),
 backgroundColor: Colors.orange,
 ),
 );
 return;
 }

 // Show user picker dialog
 final selectedUser = await _showUserPickerDialog();
 if (selectedUser == null || !mounted) return;

 _showLoadingDialog('Sending report...');

 try {
 // Generate PDF
 final pdfData = await _generatePdf();

 // Prepare message body
 final messageText = 'Inspection Report: ${_report!.clientName}\n'
 'Address: ${_report!.fullAddress}\n'
 'Date: ${DateFormat('MMM d, yyyy').format(_report!.inspectionDate)}';

 // Send via chat API
 final response = await http.post(
 Uri.parse(ApiConfig.chatMessages),
 headers: {'Content-Type': 'application/json'},
 body: jsonEncode({
 'action': 'send',
 'from_username': widget.currentUsername,
 'to_username': selectedUser,
 'message': messageText,
 'attachment_name': 'Inspection_Report_${_report!.id}.pdf',
 'attachment_data': base64Encode(pdfData),
 'attachment_type': 'pdf',
 }),
 );

 if (!mounted) return;
 Navigator.pop(context); // Close loading dialog

 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Report sent to $selectedUser'),
 backgroundColor: Colors.green,
 ),
 );
 } else {
 _showError(data['error'] ?? 'Failed to send message');
 }
 } else {
 _showError('Failed to send: HTTP ${response.statusCode}');
 }
 } catch (e) {
 if (mounted) {
 Navigator.pop(context);
 _showError('Failed to send: $e');
 }
 }
 }

 Future<String?> _showUserPickerDialog() async {
 // Fetch users list
 List<Map<String, dynamic>> users = [];
 bool loading = true;
 String? error;

 try {
 final requestingUsername = widget.currentUsername ?? '';
 final response = await http.get(
 Uri.parse('${ApiConfig.userManagement}?action=list&requesting_username=$requestingUsername'),
 headers: requestingUsername.isNotEmpty ? {'X-Username': requestingUsername} : null,
 );
 if (response.statusCode == 200) {
 final data = jsonDecode(response.body);
 if (data['success'] == true && data['users'] != null) {
 users = List<Map<String, dynamic>>.from(data['users']);
 // Filter out current user
 users = users.where((u) => u['username'] != widget.currentUsername).toList();
 }
 }
 } catch (e) {
 error = e.toString();
 }
 loading = false;

 if (!mounted) return null;

 return showDialog<String>(
 context: context,
 builder: (ctx) {
 final isDark = Theme.of(context).brightness == Brightness.dark;
 String searchQuery = '';

 return StatefulBuilder(
 builder: (context, setState) {
 final filteredUsers = users.where((u) {
 final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim().toLowerCase();
 final username = (u['username'] ?? '').toString().toLowerCase();
 final query = searchQuery.toLowerCase();
 return name.contains(query) || username.contains(query);
 }).toList();

 return AlertDialog(
 title: const Text('Send to...'),
 content: SizedBox(
 width: 350,
 height: 400,
 child: Column(
 children: [
 // Search field
 TextField(
 decoration: InputDecoration(
 hintText: 'Search users...',
 prefixIcon: const Icon(Icons.search),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(8),
 ),
 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
 ),
 onChanged: (value) => setState(() => searchQuery = value),
 ),
 const SizedBox(height: 12),
 // Users list
 Expanded(
 child: loading
 ? const Center(child: CircularProgressIndicator())
 : error != null
 ? Center(child: Text('Error: $error'))
 : filteredUsers.isEmpty
 ? Center(
 child: Text(
 searchQuery.isEmpty ? 'No users available' : 'No users found',
 style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
 ),
 )
 : ListView.builder(
 itemCount: filteredUsers.length,
 itemBuilder: (ctx, index) {
 final user = filteredUsers[index];
 final firstName = user['first_name'] ?? '';
 final lastName = user['last_name'] ?? '';
 final displayName = '$firstName $lastName'.trim();
 final username = user['username'] ?? '';
 final role = user['role'] ?? '';

 return ListTile(
 leading: CircleAvatar(
 backgroundColor: _accent.withValues(alpha: 0.2),
 child: Text(
 displayName.isNotEmpty
 ? displayName[0].toUpperCase()
 : username.isNotEmpty
 ? username[0].toUpperCase()
 : '?',
 style: const TextStyle(color: _accent, fontWeight: FontWeight.bold),
 ),
 ),
 title: Text(displayName.isNotEmpty ? displayName : username),
 subtitle: Text(
 displayName.isNotEmpty ? '@$username • $role' : role,
 style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
 ),
 onTap: () => Navigator.pop(ctx, username),
 );
 },
 ),
 ),
 ],
 ),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Cancel'),
 ),
 ],
 );
 },
 );
 },
 );
 }

 Future<void> _shareGeneric() async {
 if (_report == null) return;

 _showLoadingDialog('Preparing report...');

 try {
 final pdfFile = await _savePdfToTemp();
 if (!mounted) return;
 Navigator.pop(context);

 await Share.shareXFiles(
 [XFile(pdfFile.path)],
 subject: 'Inspection Report - ${_report!.clientName}',
 text: _getShareBody(),
 sharePositionOrigin: _getSharePositionOrigin(),
 );
 } catch (e) {
 if (mounted) {
 Navigator.pop(context);
 _showError('Failed to share: $e');
 }
 }
 }

 /// Open address in Google Maps
 Future<void> _openMaps(String address) async {
 final encodedAddress = Uri.encodeComponent(address);
 final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');

 try {
 if (await canLaunchUrl(mapsUrl)) {
 await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
 } else {
 _showError('Could not open maps');
 }
 } catch (e) {
 _showError('Failed to open maps: $e');
 }
 }

 /// Call phone number
 Future<void> _callPhone(String phone) async {
 // Clean phone number - remove non-digits except +
 final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
 final phoneUrl = Uri.parse('tel:$cleanPhone');

 try {
 if (await canLaunchUrl(phoneUrl)) {
 await launchUrl(phoneUrl);
 } else {
 // On Windows, tel: might not work, copy to clipboard instead
 if (Platform.isWindows) {
 await Clipboard.setData(ClipboardData(text: phone));
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Phone number copied: $phone'),
 backgroundColor: Colors.green,
 ),
 );
 }
 } else {
 _showError('Could not open phone dialer');
 }
 }
 } catch (e) {
 _showError('Failed to call: $e');
 }
 }

 /// Send email
 Future<void> _sendEmail(String email) async {
 final emailUrl = Uri.parse('mailto:$email');

 try {
 if (await canLaunchUrl(emailUrl)) {
 await launchUrl(emailUrl);
 } else {
 // Copy to clipboard as fallback
 await Clipboard.setData(ClipboardData(text: email));
 if (mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text('Email copied: $email'),
 backgroundColor: Colors.green,
 ),
 );
 }
 }
 } catch (e) {
 _showError('Failed to open email: $e');
 }
 }

 String _getShareBody() {
 final report = _report!;
 final dateFormat = DateFormat('MMMM d, yyyy');

 return '''
A1 Chimney Inspection Report

Client: ${report.clientName}
Address: ${report.fullAddress}
Date: ${dateFormat.format(report.inspectionDate)}
Inspector: ${report.inspectorName}
System Type: ${report.systemType}
Level: ${report.inspectionLevel}

Status: ${report.hasFailedItems ? 'NEEDS ATTENTION' : 'PASSED'}
${report.failedItems.isNotEmpty ? '\nFailed Items:\n${report.failedItems.map((i) => '- ${i.item}').join('\n')}' : ''}

Please see the attached PDF for the complete inspection report.
''';
 }

 Future<File> _savePdfToTemp() async {
 final pdfData = await _generatePdf();
 final tempDir = await getTemporaryDirectory();
 final fileName = 'Inspection_Report_${_report!.id}.pdf';
 final file = File('${tempDir.path}/$fileName');
 await file.writeAsBytes(pdfData);
 return file;
 }

 void _showLoadingDialog(String message) {
 showDialog(
 context: context,
 barrierDismissible: false,
 builder: (ctx) => AlertDialog(
 content: Row(
 children: [
 const CircularProgressIndicator(color: _accent),
 const SizedBox(width: 16),
 Expanded(child: Text(message)),
 ],
 ),
 ),
 );
 }

 void _showError(String message) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(message),
 backgroundColor: Colors.red,
 ),
 );
 }

 Future<Uint8List> _generatePdf() async {
 final report = _report!;
 final pdf = pw.Document();
 final dateFormat = DateFormat('MMMM d, yyyy');

 // Theme colors
 const primaryColor = PdfColor.fromInt(0xFF000000);
 const accentColor = PdfColor.fromInt(0xFFF49320); // A1 Orange
 const successColor = PdfColor.fromInt(0xFF1e8449);
 const errorColor = PdfColor.fromInt(0xFFc0392b);
 const neutralColor = PdfColor.fromInt(0xFF6B7280);
 const textSecondary = PdfColor.fromInt(0xFF333333);
 const textLight = PdfColor.fromInt(0xFF5d6d7e);
 const bgSecondary = PdfColor.fromInt(0xFFF5F5F5);
 const bgHighlight = PdfColor.fromInt(0xFFF8F9FA);
 const borderLight = PdfColor.fromInt(0xFFD9D9D9);
 const warningBg = PdfColor.fromInt(0xFFFEF3C7);
 const warningText = PdfColor.fromInt(0xFF92400E);

 // Font sizes
 const fontXs = 7.0;
 const fontSm = 8.0;
 const fontBase = 9.0;
 const fontMd = 10.0;
 const fontLg = 12.0;
 const fontXxl = 22.0;

 // Spacing
 const spacingXs = 2.0;
 const spacingSm = 4.0;
 const spacingMd = 8.0;
 const spacingLg = 12.0;
 const spacingXl = 16.0;

 const footerHeight = 85.0;

 // Load logos
 pw.MemoryImage? logoImage;
 pw.MemoryImage? certLogoImage;
 if (!mounted) return Uint8List(0);
 try {
 final logoData = await DefaultAssetBundle.of(context).load('assets/images/logo.png');
 logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
 } catch (e) {
  debugPrint('[InspectionReportDetailScreen] Error: $e');
}
 if (!mounted) return Uint8List(0);
 try {
 final certData = await DefaultAssetBundle.of(context).load('assets/images/csia_logo.png');
 certLogoImage = pw.MemoryImage(certData.buffer.asUint8List());
 } catch (e) {
  debugPrint('[InspectionReportDetailScreen] Error: $e');
}

 // Load report images into a map
 final Map<String, Uint8List> loadedImages = {};
 for (final img in report.images) {
 try {
 final response = await http.get(Uri.parse(img.url));
 if (response.statusCode == 200) {
 loadedImages[img.fieldName] = response.bodyBytes;
 }
 } catch (e) {
  debugPrint('[InspectionReportDetailScreen] Error: $e');
}
 }

 // Formatted data
 final inspectionDate = dateFormat.format(report.inspectionDate);
 final jobNumber = report.jobId ?? 'N/A';
 final hasFailed = report.hasFailedItems;
 const companyName = 'A1 Chimney';
 const phone = '(888) 984-4344';
 const email = 'info@a-1chimney.com';

 // Build inspection items from system data
 final inspectionItems = _buildInspectionItemsFromReport(report);
 final passedItems = inspectionItems.where((i) => i['status'] == 'pass').toList();
 final failedItemsList = inspectionItems.where((i) => i['status'] == 'fail').toList();
 final naItems = inspectionItems.where((i) => i['status'] == 'na').toList();

 // Helper functions
 pw.Widget buildSectionTitle(String title) {
 return pw.Container(
 width: double.infinity,
 padding: const pw.EdgeInsets.symmetric(vertical: spacingSm, horizontal: spacingMd),
 margin: const pw.EdgeInsets.only(bottom: spacingMd),
 decoration: const pw.BoxDecoration(
 border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2)),
 ),
 child: pw.Text(
 title,
 style: pw.TextStyle(fontSize: fontLg, fontWeight: pw.FontWeight.bold, color: primaryColor),
 ),
 );
 }

 pw.Widget buildOverviewField(String label, String? value, {PdfColor? valueColor, bool bold = false}) {
 return pw.Container(
 margin: const pw.EdgeInsets.only(bottom: spacingSm),
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Text(label, style: const pw.TextStyle(fontSize: fontSm, color: textSecondary)),
 pw.Text(
 value ?? 'N/A',
 style: pw.TextStyle(
 fontSize: fontBase,
 fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
 color: valueColor ?? primaryColor,
 ),
 ),
 ],
 ),
 );
 }

 pw.Widget buildStatusBadge(String status) {
 final isPass = status == 'pass';
 final isNa = status == 'na';
 final color = isNa ? neutralColor : (isPass ? successColor : errorColor);
 final text = isNa ? 'N/A' : (isPass ? 'PASS' : 'FAIL');
 return pw.Container(
 padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: pw.BoxDecoration(
 color: color,
 borderRadius: pw.BorderRadius.circular(3),
 ),
 child: pw.Text(
 text,
 style: pw.TextStyle(fontSize: fontXs, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
 ),
 );
 }

 pdf.addPage(
 pw.MultiPage(
 pageFormat: PdfPageFormat.letter,
 margin: const pw.EdgeInsets.only(left: 34, right: 34, top: 20, bottom: footerHeight),
 header: (context) => pw.Container(
 padding: const pw.EdgeInsets.only(bottom: spacingMd),
 decoration: const pw.BoxDecoration(
 border: pw.Border(bottom: pw.BorderSide(color: borderLight, width: 1)),
 ),
 margin: const pw.EdgeInsets.only(bottom: 28),
 child: pw.Row(
 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
 crossAxisAlignment: pw.CrossAxisAlignment.center,
 children: [
 pw.Container(
 width: 120,
 child: logoImage != null
 ? pw.Image(logoImage, height: 35)
 : pw.Text(companyName.toUpperCase(), style: pw.TextStyle(fontSize: fontLg, fontWeight: pw.FontWeight.bold)),
 ),
 pw.Expanded(
 child: pw.Column(
 mainAxisAlignment: pw.MainAxisAlignment.center,
 children: [
 pw.Row(
 mainAxisAlignment: pw.MainAxisAlignment.center,
 children: [
 pw.Text('Job #: $jobNumber', style: const pw.TextStyle(fontSize: fontBase, color: textSecondary)),
 pw.Text(' | ', style: const pw.TextStyle(fontSize: fontBase, color: textSecondary)),
 pw.Text('Date: $inspectionDate, ${report.inspectionTime}', style: const pw.TextStyle(fontSize: fontBase, color: textSecondary)),
 ],
 ),
 pw.Padding(
 padding: const pw.EdgeInsets.only(top: spacingXs),
 child: pw.Text('Technician: ${report.inspectorName}', style: const pw.TextStyle(fontSize: fontBase, color: textSecondary)),
 ),
 ],
 ),
 ),
 pw.Container(
 width: 45,
 child: certLogoImage != null ? pw.Image(certLogoImage, height: 45) : pw.SizedBox(),
 ),
 ],
 ),
 ),
 footer: (context) => pw.Container(
 decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderLight, width: 1))),
 child: pw.Column(
 children: [
 pw.Padding(
 padding: const pw.EdgeInsets.symmetric(vertical: 6),
 child: pw.Row(
 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
 children: [
 pw.Container(
 width: 100,
 child: logoImage != null
 ? pw.Image(logoImage, height: 20)
 : pw.Text(companyName.toUpperCase(), style: pw.TextStyle(fontSize: fontMd, fontWeight: pw.FontWeight.bold)),
 ),
 pw.Text('$phone | $email', style: const pw.TextStyle(fontSize: fontBase, color: textLight)),
 pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: fontBase, color: textLight)),
 ],
 ),
 ),
 pw.Container(
 padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
 margin: const pw.EdgeInsets.symmetric(vertical: 2),
 decoration: pw.BoxDecoration(color: warningBg, borderRadius: pw.BorderRadius.circular(4)),
 child: pw.Row(
 children: [
 pw.Container(
 width: 12, height: 12,
 decoration: const pw.BoxDecoration(color: accentColor, shape: pw.BoxShape.circle),
 child: pw.Center(child: pw.Text('i', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
 ),
 pw.SizedBox(width: 6),
 pw.Expanded(
 child: pw.Text(
 'NFPA 211 recommends getting your chimney cleaned and inspected once a year by a certified professional.',
 style: const pw.TextStyle(fontSize: fontBase, color: warningText),
 ),
 ),
 ],
 ),
 ),
 pw.Padding(
 padding: const pw.EdgeInsets.only(top: 2),
 child: pw.Text('Contact us today for annual maintenance program.', style: pw.TextStyle(fontSize: fontSm, fontWeight: pw.FontWeight.bold, color: accentColor), textAlign: pw.TextAlign.center),
 ),
 ],
 ),
 ),
 build: (context) => [
 // Title Section
 pw.Column(
 children: [
 pw.Text('CHIMNEY INSPECTION REPORT', style: pw.TextStyle(fontSize: fontXxl, fontWeight: pw.FontWeight.bold, color: primaryColor, letterSpacing: 1), textAlign: pw.TextAlign.center),
 pw.SizedBox(height: spacingSm),
 pw.Text('Job $jobNumber | $inspectionDate', style: const pw.TextStyle(fontSize: fontSm, color: textSecondary), textAlign: pw.TextAlign.center),
 pw.SizedBox(height: spacingLg),
 pw.Container(
 width: double.infinity,
 padding: const pw.EdgeInsets.all(spacingLg),
 decoration: pw.BoxDecoration(color: bgHighlight, borderRadius: pw.BorderRadius.circular(4)),
 child: pw.Text(
 'Thank you for trusting $companyName with your chimney inspection needs. We\'re committed to ensuring the safety and efficiency of your system.\n\nOur detailed report below provides an assessment of your system\'s current condition, identifies any safety concerns, and offers professional recommendations for maintenance or repairs. If you have any questions about our findings, please don\'t hesitate to contact our office.',
 style: const pw.TextStyle(fontSize: fontBase, color: textSecondary, lineSpacing: 1.2),
 textAlign: pw.TextAlign.justify,
 ),
 ),
 ],
 ),
 pw.SizedBox(height: spacingLg),

 // Service Overview
 buildSectionTitle('SERVICE OVERVIEW'),
 pw.Container(
 padding: const pw.EdgeInsets.all(spacingLg),
 decoration: const pw.BoxDecoration(color: bgSecondary),
 child: pw.Row(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Expanded(
 flex: 7,
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Container(
 margin: const pw.EdgeInsets.only(bottom: spacingMd),
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Text('Service Location', style: const pw.TextStyle(fontSize: fontSm, color: textSecondary)),
 pw.Text(report.fullAddress, style: pw.TextStyle(fontSize: fontBase, fontWeight: pw.FontWeight.bold)),
 ],
 ),
 ),
 pw.Row(
 children: [
 pw.Expanded(
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 buildOverviewField('Name', report.clientName),
 buildOverviewField('Inspection Result', hasFailed ? 'Fail' : 'Pass', valueColor: hasFailed ? errorColor : successColor, bold: true),
 buildOverviewField('Email', report.email1),
 buildOverviewField('Inspection Level', report.inspectionLevel),
 ],
 ),
 ),
 pw.Expanded(
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 buildOverviewField('Job Number', jobNumber),
 buildOverviewField('Primary Phone', report.phone),
 buildOverviewField('Date & Time', '$inspectionDate | ${report.inspectionTime}'),
 buildOverviewField('Reason for Inspection', report.reasonForInspection ?? 'Not Specified'),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 ),
 pw.Container(
 width: 120,
 margin: const pw.EdgeInsets.only(left: spacingMd),
 child: pw.Column(
 children: [
 pw.Container(
 height: 100,
 decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight), borderRadius: pw.BorderRadius.circular(4)),
 child: loadedImages.containsKey('exterior_home_img')
 ? pw.ClipRRect(horizontalRadius: 4, verticalRadius: 4, child: pw.Image(pw.MemoryImage(loadedImages['exterior_home_img']!), fit: pw.BoxFit.cover))
 : pw.Center(child: pw.Text('No Image', style: const pw.TextStyle(fontSize: fontXs, color: textLight))),
 ),
 pw.SizedBox(height: spacingXs),
 pw.Text('Exterior Home Image', style: const pw.TextStyle(fontSize: fontXs, color: textLight), textAlign: pw.TextAlign.center),
 ],
 ),
 ),
 ],
 ),
 ),
 pw.SizedBox(height: spacingMd),

 // System Details
 buildSectionTitle('SYSTEM DETAILS'),
 pw.Container(
 padding: const pw.EdgeInsets.all(spacingLg),
 decoration: const pw.BoxDecoration(color: bgSecondary),
 child: pw.Row(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Expanded(
 flex: 7,
 child: pw.Row(
 children: [
 pw.Expanded(
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 buildOverviewField('System Type', report.systemType),
 if (report.systemData['f_width'] != null) buildOverviewField('Width', '${report.systemData['f_width']} inches'),
 ],
 ),
 ),
 pw.Expanded(
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 if (report.systemData['f_height'] != null) buildOverviewField('Height', '${report.systemData['f_height']} inches'),
 if (report.systemData['f_depth'] != null) buildOverviewField('Depth', '${report.systemData['f_depth']} inches'),
 ],
 ),
 ),
 ],
 ),
 ),
 pw.Container(
 width: 120,
 margin: const pw.EdgeInsets.only(left: spacingMd),
 child: pw.Column(
 children: [
 pw.Container(
 height: 100,
 decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight), borderRadius: pw.BorderRadius.circular(4)),
 child: _getSystemImage(loadedImages, report.systemType) != null
 ? pw.ClipRRect(horizontalRadius: 4, verticalRadius: 4, child: pw.Image(pw.MemoryImage(_getSystemImage(loadedImages, report.systemType)!), fit: pw.BoxFit.cover))
 : pw.Center(child: pw.Text('No Image', style: const pw.TextStyle(fontSize: fontXs, color: textLight))),
 ),
 pw.SizedBox(height: spacingXs),
 pw.Text('System Image', style: const pw.TextStyle(fontSize: fontXs, color: textLight), textAlign: pw.TextAlign.center),
 ],
 ),
 ),
 ],
 ),
 ),
 pw.SizedBox(height: spacingXl),

 // Inspection Findings
 buildSectionTitle('INSPECTION FINDINGS'),
 ...inspectionItems.map((item) {
 final status = item['status'] as String;
 final label = item['label'] as String;
 final resultText = item['resultText'] as String;
 final repairNeeds = item['repairNeeds'] as String?;
 final issueCode = item['issueCode'] as String?;
 final imageKey = item['imageKey'] as String?;
 final isFailed = status == 'fail';

 return pw.Container(
 margin: const pw.EdgeInsets.only(bottom: spacingSm),
 padding: const pw.EdgeInsets.all(spacingMd),
 decoration: pw.BoxDecoration(
 border: pw.Border(left: pw.BorderSide(color: isFailed ? errorColor : (status == 'na' ? neutralColor : successColor), width: 3)),
 color: bgSecondary,
 ),
 child: pw.Column(
 crossAxisAlignment: pw.CrossAxisAlignment.start,
 children: [
 pw.Row(
 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
 children: [
 pw.Expanded(
 child: pw.Row(
 children: [
 pw.Text(label, style: pw.TextStyle(fontSize: fontBase, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(width: spacingSm),
 pw.Text(resultText, style: const pw.TextStyle(fontSize: fontSm, color: textSecondary)),
 ],
 ),
 ),
 buildStatusBadge(status),
 ],
 ),
 if (isFailed && (repairNeeds != null || issueCode != null)) ...[
 pw.SizedBox(height: spacingSm),
 if (repairNeeds != null)
 pw.Text('Repair Needs: $repairNeeds', style: const pw.TextStyle(fontSize: fontSm, color: textSecondary)),
 if (issueCode != null) ...[
 pw.SizedBox(height: spacingXs),
 pw.Text('Issue Code: $issueCode', style: const pw.TextStyle(fontSize: fontSm, color: errorColor)),
 ],
 ],
 if (isFailed && imageKey != null && loadedImages.containsKey(imageKey)) ...[
 pw.SizedBox(height: spacingMd),
 pw.Container(
 height: 120,
 width: 180,
 child: pw.Image(pw.MemoryImage(loadedImages[imageKey]!), fit: pw.BoxFit.cover),
 ),
 pw.Text(label, style: const pw.TextStyle(fontSize: fontXs, color: textLight)),
 ],
 ],
 ),
 );
 }),

 // Photo Gallery
 if (loadedImages.isNotEmpty) ...[
 pw.SizedBox(height: spacingXl),
 buildSectionTitle('PHOTO GALLERY'),
 pw.Wrap(
 spacing: spacingMd,
 runSpacing: spacingMd,
 children: loadedImages.entries.map((entry) {
 return pw.Container(
 width: 240,
 child: pw.Column(
 children: [
 pw.Container(
 height: 160,
 decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight), borderRadius: pw.BorderRadius.circular(4)),
 child: pw.ClipRRect(horizontalRadius: 4, verticalRadius: 4, child: pw.Image(pw.MemoryImage(entry.value), fit: pw.BoxFit.cover)),
 ),
 pw.SizedBox(height: spacingXs),
 pw.Text(_formatLabel(entry.key), style: const pw.TextStyle(fontSize: fontSm, color: textSecondary), textAlign: pw.TextAlign.center),
 ],
 ),
 );
 }).toList(),
 ),
 ],

 // Inspection Summary
 pw.SizedBox(height: spacingXl),
 buildSectionTitle('INSPECTION SUMMARY'),
 pw.Container(
 padding: const pw.EdgeInsets.all(spacingMd),
 decoration: pw.BoxDecoration(border: pw.Border.all(color: borderLight)),
 child: pw.Column(
 children: [
 pw.Container(
 padding: const pw.EdgeInsets.symmetric(vertical: spacingSm),
 child: pw.Row(
 children: [
 pw.Expanded(child: pw.Text('Total: ${inspectionItems.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontBase))),
 pw.Expanded(child: pw.Text('Pass: ${passedItems.length}', style: pw.TextStyle(color: successColor, fontWeight: pw.FontWeight.bold, fontSize: fontBase))),
 pw.Expanded(child: pw.Text('Fail: ${failedItemsList.length}', style: pw.TextStyle(color: errorColor, fontWeight: pw.FontWeight.bold, fontSize: fontBase))),
 pw.Expanded(child: pw.Text('N/A: ${naItems.length}', style: pw.TextStyle(color: neutralColor, fontWeight: pw.FontWeight.bold, fontSize: fontBase))),
 ],
 ),
 ),
 pw.Divider(color: borderLight),
 pw.Table(
 columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(3)},
 children: [
 pw.TableRow(
 decoration: const pw.BoxDecoration(color: bgHighlight),
 children: [
 pw.Padding(padding: const pw.EdgeInsets.all(spacingSm), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSm))),
 pw.Padding(padding: const pw.EdgeInsets.all(spacingSm), child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSm))),
 pw.Padding(padding: const pw.EdgeInsets.all(spacingSm), child: pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: fontSm))),
 ],
 ),
 ...inspectionItems.map((item) {
 final status = item['status'] as String;
 final statusColor = status == 'pass' ? successColor : (status == 'fail' ? errorColor : neutralColor);
 return pw.TableRow(
 children: [
 pw.Padding(padding: const pw.EdgeInsets.all(spacingSm), child: pw.Text(item['label'] as String, style: const pw.TextStyle(fontSize: fontSm))),
 pw.Padding(padding: const pw.EdgeInsets.all(spacingSm), child: pw.Text(status.toUpperCase(), style: pw.TextStyle(fontSize: fontSm, fontWeight: pw.FontWeight.bold, color: statusColor))),
 pw.Padding(padding: const pw.EdgeInsets.all(spacingSm), child: pw.Text(item['resultText'] as String, style: const pw.TextStyle(fontSize: fontSm, color: textSecondary))),
 ],
 );
 }),
 ],
 ),
 ],
 ),
 ),

 // Terms and Conditions
 pw.SizedBox(height: spacingXl),
 buildSectionTitle('A1 CHIMNEY TERMS AND CONDITIONS'),
 pw.Container(
 padding: const pw.EdgeInsets.all(spacingMd),
 child: pw.Text(_termsAndConditions, style: const pw.TextStyle(fontSize: fontSm, color: textSecondary, lineSpacing: 1.3)),
 ),

 // Signatures
 pw.SizedBox(height: spacingXl),
 pw.Row(
 children: [
 pw.Expanded(
 child: pw.Column(
 children: [
 pw.Text('Customer Signature', style: pw.TextStyle(fontSize: fontBase, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: spacingLg),
 pw.Container(height: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderLight)))),
 pw.SizedBox(height: spacingXs),
 pw.Text('Signed on: ${DateFormat('MM/dd/yyyy').format(report.inspectionDate)}', style: const pw.TextStyle(fontSize: fontSm, color: textSecondary)),
 ],
 ),
 ),
 pw.SizedBox(width: spacingXl),
 pw.Expanded(
 child: pw.Column(
 children: [
 pw.Text('Technician Signature', style: pw.TextStyle(fontSize: fontBase, fontWeight: pw.FontWeight.bold)),
 pw.SizedBox(height: spacingLg),
 pw.Container(height: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderLight)))),
 pw.SizedBox(height: spacingXs),
 pw.Text('Signed on: ${DateFormat('MM/dd/yyyy').format(report.inspectionDate)}', style: const pw.TextStyle(fontSize: fontSm, color: textSecondary)),
 ],
 ),
 ),
 ],
 ),
 ],
 ),
 );

 return pdf.save();
 }

 // Helper to build inspection items from report data
 List<Map<String, dynamic>> _buildInspectionItemsFromReport(InspectionReportDetail report) {
 final items = <Map<String, dynamic>>[];

 // Mapping of field keys to display labels and related info
 final fieldMappings = <String, Map<String, String>>{
 'fireplace_clearance_to_combustibles': {'label': 'Clearance To Combustible', 'imageKey': 'clearance_failure'},
 'firebox_condition': {'label': 'Firebox Condition', 'code': 'R1001.5 FIREBOX WALLS', 'imageKey': 'firebox_failure'},
 'ash_dump': {'label': 'Ash Dump', 'imageKey': 'ash_dump_failure'},
 'gas_line': {'label': 'Gas Line', 'code': 'R1001.13 GAS LINES', 'imageKey': 'gas_line_failure'},
 'damper': {'label': 'Damper', 'imageKey': 'damper_failure'},
 'smoke_chamber': {'label': 'Smoke Chamber', 'imageKey': 'smoke_chamber_failure'},
 'masonry_soot': {'label': 'Soot Condition', 'code': 'NFPA 211', 'imageKey': 'soot_condition_img'},
 'chimney_liner': {'label': 'Chimney Liner', 'code': 'R1003.11 FLUE LINING', 'imageKey': 'chimney_liner_img'},
 'chimney_height_from_roof_line': {'label': 'Chimney Height From Roof Line', 'imageKey': 'chimney_height_failure'},
 'chimney_cricket': {'label': 'Chimney Cricket', 'imageKey': 'chimney_cricket_failure'},
 'flushing_condition': {'label': 'Flashing Condition', 'imageKey': 'flashing_failure'},
 'masonry_work_condition': {'label': 'Masonry Work Condition', 'imageKey': 'masonry_work_failure'},
 'chimney_crown_condition': {'label': 'Chimney Crown Condition', 'code': 'R1003.9.1 CHIMNEY CAP/CROWN', 'imageKey': 'chimney_crown_failure'},
 'chimney_rain_cap': {'label': 'Chimney Rain Cap', 'imageKey': 'chimney_rain_cap_img'},
 'chimney_spark_arrestor': {'label': 'Chimney Spark Arrestor', 'imageKey': 'spark_arrestor_failure'},
 };

 // Combine all data sources
 final allData = <String, dynamic>{
 ...report.systemData,
 ...report.chimneyData,
 ...report.exteriorData,
 };

 for (final entry in fieldMappings.entries) {
 final key = entry.key;
 final mapping = entry.value;
 final value = allData[key];

 if (value == null) continue;

 String status = 'pass';
 final String resultText = value.toString();
 String? repairNeeds;

 // Determine status based on value
 if (value.toString().toLowerCase().contains('does not') ||
 value.toString().toLowerCase().contains('fail') ||
 value.toString().toLowerCase().contains('buildup') ||
 value.toString().toLowerCase().contains('heavy') ||
 value.toString().toLowerCase().contains('glazed')) {
 status = 'fail';
 repairNeeds = allData['${key}_repair_needs']?.toString() ?? allData['firebox_repair_needs']?.toString();
 } else if (value.toString().toLowerCase().contains('not exist') ||
 value.toString().toLowerCase().contains('n/a') ||
 value.toString().toLowerCase().contains('does not need')) {
 status = 'na';
 }

 items.add({
 'label': mapping['label']!,
 'status': status,
 'resultText': resultText,
 'repairNeeds': repairNeeds,
 'issueCode': status == 'fail' ? mapping['code'] : null,
 'imageKey': mapping['imageKey'],
 });
 }

 return items;
 }

 // Helper to get system-specific image
 Uint8List? _getSystemImage(Map<String, Uint8List> images, String systemType) {
 final systemImageKeys = {
 'Masonry Fireplace': ['firebox_img', 'masonry_fireplace_img', 'fireplace_img'],
 'Built-In Fireplace': ['built_in_fireplace_img', 'fireplace_img'],
 'Wood Stove': ['wood_stove_img', 'stove_img'],
 'Furnace': ['furnace_img', 'furnace_visual_img'],
 'Electric': ['electric_fireplace_img'],
 };

 final keys = systemImageKeys[systemType] ?? [];
 for (final key in keys) {
 if (images.containsKey(key)) return images[key];
 }
 return null;
 }

 static const String _termsAndConditions = '''1. Introduction
These terms and conditions "Terms" govern the use of the inspection report "Report" provided by Plano "Company", "we", "us", or "our". By accepting and using the Report, the client "Client", "you", or "your" agrees to be bound by these Terms. If you do not agree to these Terms, please do not use the Report.

2. Scope of the Report
2.1 The Report is prepared based on a visual inspection of the accessible areas and systems of the chimney on the date of the inspection.
2.2 The Report is intended to provide an overview of the condition of the chimney and is not an exhaustive list of every potential issue or defect.
2.3 The Report is not a warranty or guarantee of any kind regarding the condition of the chimney, and the Company does not assume any liability for any issues not identified in the Report.

3. Limitations and Exclusions
3.1 The inspection and the Report are limited to the visible and accessible areas of the chimney. Concealed or inaccessible areas are not included in the inspection.
3.2 The inspection does not cover areas that require the dismantling of components, destructive testing, or specialized equipment to access.
3.3 The Report does not include an evaluation of environmental hazards, such as asbestos, lead, mold, radon, or other contaminants, unless specifically agreed upon and documented in the inspection agreement.
3.4 The inspection and Report do not include an assessment of compliance with building codes, zoning laws, or other regulations.

4. Client Responsibilities
4.1 The Client is responsible for providing the Company with accurate and complete information regarding the chimney to be inspected.
4.2 The Client must ensure that the Company has safe and unobstructed access to the chimney and its systems.
4.3 The Client should carefully review the Report and promptly notify the Company of any questions or concerns.

5. Fees and Payment
5.1 The fees for the inspection services are as agreed upon between the Client and the Company and must be paid in full prior to the delivery of the Report.
5.2 Any additional services requested by the Client that are outside the scope of the initial agreement may incur additional charges.

6. Limitation of Liability
6.1 To the fullest extent permitted by law, the Company's total liability to the Client for any claims arising out of or related to the inspection or the Report is limited to the amount paid by the Client for the inspection services.
6.2 The Company is not liable for any indirect, incidental, special, or consequential damages, including but not limited to lost profits, loss of use, or any other economic loss.

7. Dispute Resolution
7.1 Any disputes arising out of or related to these Terms or the inspection services provided by the Company shall be resolved through mediation. If mediation is unsuccessful, the dispute shall be resolved through binding arbitration in accordance with the rules of [arbitration organization], to be conducted in TX.

8. Governing Law
These Terms are governed by and construed in accordance with the laws of the state of TX, without regard to its conflict of law principles.

9. Amendments
The Company reserves the right to amend these Terms at any time. Any amendments will be effective immediately upon posting the updated Terms on the Company's website or otherwise notifying the Client.

10. Acceptance of Terms
By accepting and using the Report, the Client acknowledges that they have read, understood, and agreed to be bound by these Terms.''';

 @override
 Widget build(BuildContext context) {
 final isDark = Theme.of(context).brightness == Brightness.dark;

 return Scaffold(
 backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
 appBar: AppBar(
 title: const Text('Inspection Report'),
 backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
 foregroundColor: isDark ? Colors.white : Colors.black,
 elevation: 0,
 actions: [
 if (_report != null) ...[
 IconButton(
 icon: const Icon(Icons.share),
 onPressed: _showShareOptions,
 tooltip: 'Share Report',
 ),
 IconButton(
 icon: const Icon(Icons.print),
 onPressed: _printReport,
 tooltip: 'Print Report',
 ),
 ],
 if (widget.isAdmin && _report != null)
 IconButton(
 icon: const Icon(Icons.delete_outline, color: Colors.red),
 onPressed: _deleteReport,
 ),
 ],
 ),
 body: _loading
 ? const Center(child: CircularProgressIndicator(color: _accent))
 : _error != null
 ? Center(
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Icons.error_outline,
 size: 48, color: Colors.red[300]),
 const SizedBox(height: 16),
 Text(_error!, textAlign: TextAlign.center),
 const SizedBox(height: 16),
 ElevatedButton.icon(
 onPressed: _loadReport,
 icon: const Icon(Icons.refresh),
 label: const Text('Retry'),
 style: ElevatedButton.styleFrom(
 backgroundColor: _accent,
 ),
 ),
 ],
 ),
 )
 : _report != null
 ? _buildContent(isDark)
 : const SizedBox.shrink(),
 );
 }

 Widget _buildContent(bool isDark) {
 final report = _report!;
 final dateFormat = DateFormat('MMMM d, yyyy');

 return SingleChildScrollView(
 padding: const EdgeInsets.all(16),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Header card with basic info
 _buildCard(
 isDark,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 4),
 decoration: BoxDecoration(
 color: _accent,
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 report.inspectionLevel,
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 12,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Container(
 padding: const EdgeInsets.symmetric(
 horizontal: 12, vertical: 4),
 decoration: BoxDecoration(
 color: report.hasFailedItems
 ? Colors.red.withValues(alpha: 0.15)
 : Colors.green.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 report.hasFailedItems ? 'Needs Attention' : 'Passed',
 style: TextStyle(
 color:
 report.hasFailedItems ? Colors.red : Colors.green,
 fontWeight: FontWeight.w600,
 fontSize: 12,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 16),
 Text(
 report.clientName,
 style: const TextStyle(
 fontSize: 20,
 fontWeight: FontWeight.bold,
 ),
 ),
 const SizedBox(height: 8),
 _buildInfoRow(
 Icons.location_on,
 report.fullAddress,
 onTap: () => _openMaps(report.fullAddress),
 ),
 if (report.phone?.isNotEmpty == true)
 _buildInfoRow(
 Icons.phone,
 report.phone!,
 onTap: () => _callPhone(report.phone!),
 ),
 if (report.email1?.isNotEmpty == true)
 _buildInfoRow(
 Icons.email,
 report.email1!,
 onTap: () => _sendEmail(report.email1!),
 ),
 const Divider(height: 24),
 Row(
 children: [
 Expanded(
 child: _buildDetailItem(
 'Date', dateFormat.format(report.inspectionDate)),
 ),
 Expanded(
 child: _buildDetailItem('Time', report.inspectionTime),
 ),
 ],
 ),
 const SizedBox(height: 8),
 Row(
 children: [
 Expanded(
 child: _buildDetailItem('Inspector', report.inspectorName),
 ),
 Expanded(
 child: _buildDetailItem('System', report.systemType),
 ),
 ],
 ),
 if (report.reasonForInspection?.isNotEmpty == true) ...[
 const SizedBox(height: 8),
 _buildDetailItem('Reason', report.reasonForInspection!),
 ],
 ],
 ),
 ),

 // Failed Items section
 if (report.failedItems.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSectionHeader('Failed Items', Icons.warning, Colors.red),
 const SizedBox(height: 8),
 _buildCard(
 isDark,
 child: Column(
 children: report.failedItems.map((item) {
 return Padding(
 padding: const EdgeInsets.only(bottom: 12),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Icons.error, color: Colors.red, size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 item.item,
 style: const TextStyle(
 fontWeight: FontWeight.w600,
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 4),
 Text(
 item.code,
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white54 : Colors.black54,
 ),
 ),
 ],
 ),
 );
 }).toList(),
 ),
 ),
 ],

 // System-specific data
 if (report.systemData.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSectionHeader(
 '${report.systemType} Details', Icons.settings, _accent),
 const SizedBox(height: 8),
 _buildDataCard(isDark, report.systemData),
 ],

 // Chimney data
 if (report.chimneyData.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSectionHeader('Chimney Details', Icons.home, _accent),
 const SizedBox(height: 8),
 _buildDataCard(isDark, report.chimneyData),
 ],

 // Exterior data (Level 2+)
 if (report.exteriorData.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSectionHeader(
 'Exterior/Roof Inspection', Icons.roofing, _accent),
 const SizedBox(height: 8),
 _buildDataCard(isDark, report.exteriorData),
 ],

 // Inspector notes
 if (report.inspectorNote?.isNotEmpty == true) ...[
 const SizedBox(height: 16),
 _buildSectionHeader('Inspector Notes', Icons.note, _accent),
 const SizedBox(height: 8),
 _buildCard(
 isDark,
 child: Text(report.inspectorNote!),
 ),
 ],

 // Estimate / Invoice Items
 if (report.hasInvoiceItems) ...[
 const SizedBox(height: 16),
 _buildSectionHeader('Recommended Services', Icons.receipt_long, Colors.green),
 const SizedBox(height: 8),
 _buildEstimateCard(isDark, report),
 ],

 // Images
 if (report.images.isNotEmpty) ...[
 const SizedBox(height: 16),
 _buildSectionHeader(
 'Photos (${report.images.length})', Icons.photo_library, _accent),
 const SizedBox(height: 8),
 _buildImagesGrid(isDark, report.images),
 ],

 const SizedBox(height: 32),
 ],
 ),
 );
 }

 Widget _buildCard(bool isDark, {required Widget child}) {
 return Container(
 width: double.infinity,
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

 Widget _buildInfoRow(IconData icon, String text, {VoidCallback? onTap}) {
 final content = Padding(
 padding: const EdgeInsets.only(bottom: 6),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Icon(icon, size: 16, color: _accent),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 text,
 style: onTap != null
 ? const TextStyle(
 decoration: TextDecoration.underline,
 decorationColor: Colors.orange,
 )
 : null,
 ),
 ),
 if (onTap != null)
 Icon(Icons.open_in_new, size: 14, color: Colors.grey.shade500),
 ],
 ),
 );

 if (onTap != null) {
 return InkWell(
 onTap: onTap,
 borderRadius: BorderRadius.circular(4),
 child: content,
 );
 }
 return content;
 }

 Widget _buildDetailItem(String label, String value) {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 label,
 style: const TextStyle(
 fontSize: 11,
 color: Colors.grey,
 ),
 ),
 const SizedBox(height: 2),
 Text(
 value,
 style: const TextStyle(fontWeight: FontWeight.w500),
 ),
 ],
 );
 }

 Widget _buildSectionHeader(String title, IconData icon, Color color) {
 return Row(
 children: [
 Icon(icon, size: 20, color: color),
 const SizedBox(width: 8),
 Text(
 title,
 style: TextStyle(
 fontSize: 16,
 fontWeight: FontWeight.bold,
 color: color,
 ),
 ),
 ],
 );
 }

 Widget _buildDataCard(bool isDark, Map<String, dynamic> data) {
 final entries = data.entries
 .where((e) => e.value != null && e.value.toString().isNotEmpty)
 .toList();

 if (entries.isEmpty) {
 return _buildCard(
 isDark,
 child: Text(
 'No data recorded',
 style: TextStyle(
 color: isDark ? Colors.white38 : Colors.black38,
 fontStyle: FontStyle.italic,
 ),
 ),
 );
 }

 return _buildCard(
 isDark,
 child: Column(
 children: entries.map((entry) {
 final label = _formatLabel(entry.key);
 final value = entry.value.toString();
 final status = _getItemStatus(value);

 return Padding(
 padding: const EdgeInsets.only(bottom: 8),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 flex: 2,
 child: Text(
 label,
 style: TextStyle(
 fontSize: 13,
 color: isDark ? Colors.white54 : Colors.black54,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 flex: 3,
 child: Text(
 value,
 style: TextStyle(
 fontWeight: FontWeight.w500,
 color: _getValueColor(value),
 ),
 ),
 ),
 const SizedBox(width: 8),
 _buildStatusBadge(status, isDark),
 ],
 ),
 );
 }).toList(),
 ),
 );
 }

 /// Determine status based on value content
 String _getItemStatus(String value) {
 final lower = value.toLowerCase();
 if (lower.contains('does not meet') ||
     lower.contains('does not exist') ||
     lower.contains('failed') ||
     lower.contains('unsealed') ||
     lower.contains('unconnected') ||
     lower.contains('heavy buildup') ||
     lower.contains('glazed')) {
   return 'fail';
 }
 if (lower.contains('n/a') ||
     lower.contains('not applicable') ||
     lower.contains('does not need')) {
   return 'na';
 }
 if (lower.contains('meets') ||
     lower.contains('passed') ||
     lower.contains('good') ||
     lower.contains('sealed') ||
     lower.contains('connected') ||
     lower.contains('light') ||
     lower.contains('moderate') ||
     lower.contains('exists') ||
     lower.contains('yes')) {
   return 'pass';
 }
 return 'na'; // Default for non-inspectable fields
 }

 /// Build a status badge widget
 Widget _buildStatusBadge(String status, bool isDark) {
 Color bgColor;
 Color textColor;
 String text;

 switch (status) {
   case 'pass':
     bgColor = Colors.green.withValues(alpha: 0.15);
     textColor = Colors.green;
     text = 'PASS';
     break;
   case 'fail':
     bgColor = Colors.red.withValues(alpha: 0.15);
     textColor = Colors.red;
     text = 'FAIL';
     break;
   default:
     bgColor = Colors.grey.withValues(alpha: 0.15);
     textColor = isDark ? Colors.white54 : Colors.black54;
     text = 'N/A';
 }

 return Container(
   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
   decoration: BoxDecoration(
     color: bgColor,
     borderRadius: BorderRadius.circular(4),
   ),
   child: Text(
     text,
     style: TextStyle(
       fontSize: 10,
       fontWeight: FontWeight.bold,
       color: textColor,
     ),
   ),
 );
 }

 Widget _buildEstimateCard(bool isDark, InspectionReportDetail report) {
 return _buildCard(
 isDark,
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // Items list
 ...report.invoiceItems.map((item) {
 final name = item['item_name'] ?? item['name'] ?? 'Service Item';
 final description = item['description'] ?? '';
 final priceCents = item['price_cents'] ?? item['price'] ?? 0;
 final quantity = item['quantity'] ?? 1;
 final price = (priceCents is int ? priceCents : int.tryParse(priceCents.toString()) ?? 0) / 100;
 final lineTotal = price * quantity;

 return Container(
 padding: const EdgeInsets.symmetric(vertical: 8),
 decoration: BoxDecoration(
 border: Border(
 bottom: BorderSide(
 color: isDark ? Colors.white12 : Colors.black12,
 ),
 ),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 name,
 style: const TextStyle(fontWeight: FontWeight.w600),
 ),
 if (description.isNotEmpty)
 Padding(
 padding: const EdgeInsets.only(top: 2),
 child: Text(
 description,
 style: TextStyle(
 fontSize: 12,
 color: isDark ? Colors.white54 : Colors.black54,
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(width: 8),
 Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 children: [
 Text(
 '\$${lineTotal.toStringAsFixed(2)}',
 style: const TextStyle(fontWeight: FontWeight.w600),
 ),
 if (quantity > 1)
 Text(
 '$quantity x \$${price.toStringAsFixed(2)}',
 style: TextStyle(
 fontSize: 11,
 color: isDark ? Colors.white38 : Colors.black38,
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }),

 // Total
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 const Text(
 'TOTAL ESTIMATE',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 fontSize: 14,
 ),
 ),
 Text(
 report.totalEstimateDisplay,
 style: const TextStyle(
 fontWeight: FontWeight.bold,
 fontSize: 18,
 color: Colors.green,
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }

 String _formatLabel(String key) {
 // Convert snake_case or camelCase to Title Case
 return key
 .replaceAllMapped(RegExp(r'[_-]'), (_) => ' ')
 .replaceAllMapped(
 RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
 .trim()
 .split(' ')
 .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
 .join(' ');
 }

 Color? _getValueColor(String value) {
 final lower = value.toLowerCase();
 if (lower.contains('does not meet') ||
 lower.contains('failed') ||
 lower.contains('unsealed') ||
 lower.contains('unconnected') ||
 lower.contains('does not exist')) {
 return Colors.red;
 }
 if (lower.contains('meets') ||
 lower.contains('passed') ||
 lower.contains('good') ||
 lower.contains('sealed') ||
 lower.contains('connected')) {
 return Colors.green;
 }
 return null;
 }

 Widget _buildImagesGrid(bool isDark, List<ReportImage> images) {
 return GridView.builder(
 shrinkWrap: true,
 physics: const NeverScrollableScrollPhysics(),
 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
 crossAxisCount: 2,
 crossAxisSpacing: 8,
 mainAxisSpacing: 8,
 childAspectRatio: 1,
 ),
 itemCount: images.length,
 itemBuilder: (context, index) {
 final image = images[index];
 return GestureDetector(
 onTap: () => _showImageFullscreen(image),
 child: Container(
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(8),
 border: Border.all(
 color: isDark ? Colors.white12 : Colors.black12,
 ),
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(8),
 child: Stack(
 fit: StackFit.expand,
 children: [
 Image.network(
 image.url,
 fit: BoxFit.cover,
 errorBuilder: (_, __, ___) => Container(
 color: isDark ? Colors.white10 : Colors.grey[200],
 child: const Icon(Icons.broken_image, size: 32),
 ),
 loadingBuilder: (_, child, progress) {
 if (progress == null) return child;
 return Center(
 child: CircularProgressIndicator(
 value: progress.expectedTotalBytes != null
 ? progress.cumulativeBytesLoaded /
 progress.expectedTotalBytes!
 : null,
 color: _accent,
 strokeWidth: 2,
 ),
 );
 },
 ),
 Positioned(
 bottom: 0,
 left: 0,
 right: 0,
 child: Container(
 padding: const EdgeInsets.all(4),
 color: Colors.black54,
 child: Text(
 _formatLabel(image.fieldName),
 style: const TextStyle(
 color: Colors.white,
 fontSize: 10,
 ),
 textAlign: TextAlign.center,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ),
 ],
 ),
 ),
 ),
 );
 },
 );
 }

 void _showImageFullscreen(ReportImage image) {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => Scaffold(
 backgroundColor: Colors.black,
 appBar: AppBar(
 backgroundColor: Colors.black,
 foregroundColor: Colors.white,
 title: Text(_formatLabel(image.fieldName)),
 ),
 body: Center(
 child: InteractiveViewer(
 child: Image.network(
 image.url,
 fit: BoxFit.contain,
 errorBuilder: (_, __, ___) => const Icon(
 Icons.broken_image,
 size: 64,
 color: Colors.white54,
 ),
 ),
 ),
 ),
 ),
 ),
 );
 }
}
