import 'package:flutter/material.dart';
import '../../../app_theme.dart';
import 'web_management_service.dart';

/// Tab for editing site information (business, contact, address, hours)
class SiteInfoTab extends StatefulWidget {
  final WebsiteVariables variables;
  final Function(WebsiteVariables) onChanged;

  const SiteInfoTab({
    super.key,
    required this.variables,
    required this.onChanged,
  });

  @override
  State<SiteInfoTab> createState() => _SiteInfoTabState();
}

class _SiteInfoTabState extends State<SiteInfoTab> {
  static const Color _accent = AppColors.accent;

  late TextEditingController _businessNameController;
  late TextEditingController _cityNameController;
  late TextEditingController _locationNameController;
  late TextEditingController _taglineController;
  late TextEditingController _googleMapsUrlController;
  late TextEditingController _phonePrimaryController;
  late TextEditingController _phoneSecondaryController;
  late TextEditingController _emailPrimaryController;
  late TextEditingController _emailSecondaryController;
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;

  // Operating hours controllers
  final Map<String, TextEditingController> _hoursControllers = {};

  static const List<String> _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const Map<String, String> _dayLabels = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
    'sun': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final v = widget.variables;

    _businessNameController = TextEditingController(text: v.businessName ?? '');
    _cityNameController = TextEditingController(text: v.cityName ?? '');
    _locationNameController = TextEditingController(text: v.locationName ?? '');
    _taglineController = TextEditingController(text: v.tagline ?? '');
    _googleMapsUrlController = TextEditingController(text: v.googleMapsUrl ?? '');
    _phonePrimaryController = TextEditingController(text: v.phonePrimary ?? '');
    _phoneSecondaryController = TextEditingController(text: v.phoneSecondary ?? '');
    _emailPrimaryController = TextEditingController(text: v.emailPrimary ?? '');
    _emailSecondaryController = TextEditingController(text: v.emailSecondary ?? '');
    _addressLine1Controller = TextEditingController(text: v.addressLine1 ?? '');
    _addressLine2Controller = TextEditingController(text: v.addressLine2 ?? '');
    _cityController = TextEditingController(text: v.city ?? '');
    _stateController = TextEditingController(text: v.state ?? '');
    _zipController = TextEditingController(text: v.zip ?? '');
    _countryController = TextEditingController(text: v.country ?? 'USA');

    // Initialize hours controllers
    for (final day in _days) {
      _hoursControllers[day] = TextEditingController(
        text: v.operatingHours?[day] ?? '',
      );
    }
  }

  @override
  void didUpdateWidget(SiteInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variables.siteId != widget.variables.siteId) {
      _disposeControllers();
      _initControllers();
      setState(() {});
    }
  }

  void _disposeControllers() {
    _businessNameController.dispose();
    _cityNameController.dispose();
    _locationNameController.dispose();
    _taglineController.dispose();
    _googleMapsUrlController.dispose();
    _phonePrimaryController.dispose();
    _phoneSecondaryController.dispose();
    _emailPrimaryController.dispose();
    _emailSecondaryController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();

    for (final controller in _hoursControllers.values) {
      controller.dispose();
    }
    _hoursControllers.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _toggleClosed(String day) {
    final controller = _hoursControllers[day];
    if (controller == null) return;

    setState(() {
      if (controller.text.toLowerCase() == 'closed') {
        controller.text = '';
      } else {
        controller.text = 'Closed';
      }
    });
    _notifyChange();
  }

  void _notifyChange() {
    final updated = WebsiteVariables(
      id: widget.variables.id,
      siteId: widget.variables.siteId,
      businessName: _businessNameController.text.isEmpty ? null : _businessNameController.text,
      cityName: _cityNameController.text.isEmpty ? null : _cityNameController.text,
      locationName: _locationNameController.text.isEmpty ? null : _locationNameController.text,
      tagline: _taglineController.text.isEmpty ? null : _taglineController.text,
      googleMapsUrl: _googleMapsUrlController.text.isEmpty ? null : _googleMapsUrlController.text,
      phonePrimary: _phonePrimaryController.text.isEmpty ? null : _phonePrimaryController.text,
      phoneSecondary: _phoneSecondaryController.text.isEmpty ? null : _phoneSecondaryController.text,
      emailPrimary: _emailPrimaryController.text.isEmpty ? null : _emailPrimaryController.text,
      emailSecondary: _emailSecondaryController.text.isEmpty ? null : _emailSecondaryController.text,
      addressLine1: _addressLine1Controller.text.isEmpty ? null : _addressLine1Controller.text,
      addressLine2: _addressLine2Controller.text.isEmpty ? null : _addressLine2Controller.text,
      city: _cityController.text.isEmpty ? null : _cityController.text,
      state: _stateController.text.isEmpty ? null : _stateController.text,
      zip: _zipController.text.isEmpty ? null : _zipController.text,
      country: _countryController.text.isEmpty ? 'USA' : _countryController.text,
      facebookUrl: widget.variables.facebookUrl,
      instagramUrl: widget.variables.instagramUrl,
      youtubeUrl: widget.variables.youtubeUrl,
      twitterUrl: widget.variables.twitterUrl,
      linkedinUrl: widget.variables.linkedinUrl,
      tiktokUrl: widget.variables.tiktokUrl,
      yelpUrl: widget.variables.yelpUrl,
      googleBusinessUrl: widget.variables.googleBusinessUrl,
      operatingHours: Map.fromEntries(
        _days.map((day) => MapEntry(day, _hoursControllers[day]?.text ?? '')),
      ),
    );

    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Business Information
              _buildSection(
                cardColor: cardColor,
                title: 'Business Information',
                icon: Icons.business,
                children: [
                  _buildTextField(
                    controller: _businessNameController,
                    label: 'Business Name',
                    hint: 'e.g., A-1 Chimney Specialist',
                    icon: Icons.store,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _cityNameController,
                          label: 'City Name',
                          hint: 'e.g., Los Angeles',
                          icon: Icons.location_city,
                          helperText: 'City for geo-targeting',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _locationNameController,
                          label: 'State',
                          hint: 'e.g., California',
                          icon: Icons.map,
                          helperText: 'State for geo-targeting',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _taglineController,
                    label: 'Tagline / Slogan',
                    hint: 'e.g., Your Trusted Chimney Experts',
                    icon: Icons.format_quote,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _googleMapsUrlController,
                    label: 'Google Maps URL',
                    hint: 'e.g., https://maps.google.com/?q=...',
                    icon: Icons.map_outlined,
                    helperText: 'Google Maps link or embed URL for your location',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contact Information
              _buildSection(
                cardColor: cardColor,
                title: 'Contact Information',
                icon: Icons.phone,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _phonePrimaryController,
                          label: 'Primary Phone',
                          hint: '(555) 123-4567',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _phoneSecondaryController,
                          label: 'Secondary Phone',
                          hint: '(555) 987-6543',
                          icon: Icons.phone_android,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _emailPrimaryController,
                          label: 'Primary Email',
                          hint: 'info@example.com',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _emailSecondaryController,
                          label: 'Secondary Email',
                          hint: 'support@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Address
              _buildSection(
                cardColor: cardColor,
                title: 'Address',
                icon: Icons.location_on,
                children: [
                  _buildTextField(
                    controller: _addressLine1Controller,
                    label: 'Address Line 1',
                    hint: '123 Main Street',
                    icon: Icons.home,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _addressLine2Controller,
                    label: 'Address Line 2',
                    hint: 'Suite 100',
                    icon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'Los Angeles',
                          icon: Icons.location_city,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _stateController,
                          label: 'State',
                          hint: 'CA',
                          icon: Icons.map,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _zipController,
                          label: 'ZIP Code',
                          hint: '90001',
                          icon: Icons.pin_drop,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _countryController,
                    label: 'Country',
                    hint: 'USA',
                    icon: Icons.flag,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Operating Hours
              _buildSection(
                cardColor: cardColor,
                title: 'Operating Hours',
                icon: Icons.access_time,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter hours in format: 8:00 AM - 5:00 PM or "Closed"',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < _days.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            _dayLabels[_days[i]]!,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _hoursControllers[_days[i]],
                            onChanged: (_) => _notifyChange(),
                            enabled: _hoursControllers[_days[i]]?.text.toLowerCase() != 'closed',
                            decoration: InputDecoration(
                              hintText: '8:00 AM - 5:00 PM',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: _hoursControllers[_days[i]]?.text.toLowerCase() == 'closed'
                              ? 'Mark as Open'
                              : 'Mark as Closed',
                          child: InkWell(
                            onTap: () => _toggleClosed(_days[i]),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _hoursControllers[_days[i]]?.text.toLowerCase() == 'closed'
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _hoursControllers[_days[i]]?.text.toLowerCase() == 'closed'
                                      ? Colors.red.withValues(alpha: 0.5)
                                      : Colors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                _hoursControllers[_days[i]]?.text.toLowerCase() == 'closed'
                                    ? Icons.lock
                                    : Icons.lock_open,
                                size: 18,
                                color: _hoursControllers[_days[i]]?.text.toLowerCase() == 'closed'
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required Color cardColor,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helperText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: (_) => _notifyChange(),
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
