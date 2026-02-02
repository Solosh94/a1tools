import 'package:flutter/material.dart';

import '../../../app_theme.dart';

/// Accent color used throughout inspection forms
const Color inspectionAccent = AppColors.accent;

/// Red color for errors and warnings
const Color inspectionRed = Color(0xFFDB2323);

/// Section header for form sections
class InspectionSectionHeader extends StatelessWidget {
  final String title;

  const InspectionSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}

/// Card container for form sections
class InspectionCard extends StatelessWidget {
  final Widget child;

  const InspectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
}

/// Input decoration for form fields
InputDecoration inspectionInputDecoration(
  String label,
  bool isDark, {
  bool hasError = false,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: hasError ? const TextStyle(color: inspectionRed) : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
          color: hasError ? inspectionRed : (isDark ? Colors.white24 : Colors.black12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: hasError ? inspectionRed : (isDark ? Colors.white24 : Colors.black12),
        width: hasError ? 2 : 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: hasError ? inspectionRed : inspectionAccent, width: 2),
    ),
    filled: true,
    fillColor: hasError
        ? inspectionRed.withValues(alpha: 0.05)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

/// Date selection button
class InspectionDateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const InspectionDateButton({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                const Icon(Icons.calendar_today, size: 16, color: inspectionAccent),
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
}

/// Condition dropdown for inspection fields
class InspectionConditionDropdown extends StatelessWidget {
  final String? value;
  final String label;
  final Function(String?) onChanged;
  final List<String> options;
  final bool hasError;

  const InspectionConditionDropdown({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    required this.options,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: inspectionInputDecoration(label, isDark, hasError: hasError),
      items: options.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: onChanged,
    );
  }
}

/// Multi-select chips for selecting multiple options
class InspectionMultiSelectChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final Function(List<String>) onChanged;

  const InspectionMultiSelectChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              selectedColor: inspectionAccent.withValues(alpha: 0.3),
              checkmarkColor: inspectionAccent,
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
}

/// Warning box for failed inspections
class InspectionFailureWarning extends StatelessWidget {
  final String code;
  final String description;

  const InspectionFailureWarning({
    super.key,
    required this.code,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inspectionRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inspectionRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: inspectionRed, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'INSPECTION FAILED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: inspectionRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: inspectionRed),
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
}

/// Info box for displaying information messages
class InspectionInfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const InspectionInfoBox({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
}
