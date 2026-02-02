import 'package:flutter/material.dart';

const Color accentOrange = Color(0xFFF49320);

Widget buildHomeButton(String label, VoidCallback onTap, {BuildContext? context}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? accentOrange : Colors.black,
            side: const BorderSide(color: accentOrange, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return accentOrange.withValues(alpha: 0.15);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return accentOrange.withValues(alpha: 0.08);
              }
              return null;
            }),
          ),
          onPressed: onTap,
          child: Text(label),
        );
      },
    ),
  );
}