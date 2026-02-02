/// Rating Cell Widget
/// Displays and edits star rating values (1-5 stars)
library;

import 'package:flutter/material.dart';

class RatingCell extends StatelessWidget {
  final dynamic value;
  final Function(int) onChanged;
  final int maxStars;
  final bool compact;

  const RatingCell({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxStars = 5,
    this.compact = false,
  });

  int get _rating {
    if (value == null) return 0;
    if (value is int) return value.clamp(0, maxStars);
    if (value is double) return value.round().clamp(0, maxStars);
    final parsed = int.tryParse(value.toString()) ?? 0;
    return parsed.clamp(0, maxStars);
  }

  @override
  Widget build(BuildContext context) {
    final rating = _rating;
    final starSize = compact ? 16.0 : 20.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= rating;

        return GestureDetector(
          onTap: () {
            // If tapping the same star that's already selected, clear the rating
            if (starIndex == rating) {
              onChanged(0);
            } else {
              onChanged(starIndex);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 1.0 : 2.0),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              size: starSize,
              color: isFilled ? Colors.amber : Colors.grey.shade400,
            ),
          ),
        );
      }),
    );
  }
}
