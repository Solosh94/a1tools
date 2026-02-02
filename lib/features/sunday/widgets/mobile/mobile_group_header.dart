/// Mobile Group Header Widget
/// Compact group header for mobile with collapse toggle
library;

import 'package:flutter/material.dart';
import '../../models/sunday_models.dart';

class MobileGroupHeader extends StatelessWidget {
  final SundayGroup group;
  final bool isCollapsed;
  final int itemCount;
  final VoidCallback onToggleCollapse;

  const MobileGroupHeader({
    super.key,
    required this.group,
    required this.isCollapsed,
    required this.itemCount,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = group.colorValue.withValues(alpha: isDark ? 0.2 : 0.1);
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onToggleCollapse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            left: BorderSide(color: group.colorValue, width: 4),
            bottom: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
          ),
        ),
        child: Row(
          children: [
            // Collapse/expand icon
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: group.colorValue,
              ),
            ),
            const SizedBox(width: 8),
            // Group title
            Expanded(
              child: Text(
                group.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Item count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: group.colorValue.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$itemCount',
                style: TextStyle(
                  color: group.colorValue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
