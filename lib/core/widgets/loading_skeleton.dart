// Loading Skeleton Widgets
//
// Shimmer/skeleton loading animations for better UX during data loading.
// Provides visual placeholders that match the eventual content layout.

import 'package:flutter/material.dart';

/// Configuration for shimmer animation
class ShimmerConfig {
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerConfig({
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
    this.duration = const Duration(milliseconds: 1500),
  });

  /// Dark theme shimmer config
  factory ShimmerConfig.dark() {
    return const ShimmerConfig(
      baseColor: Color(0xFF2A2A2A),
      highlightColor: Color(0xFF3A3A3A),
    );
  }

  /// Get config based on theme brightness
  factory ShimmerConfig.fromBrightness(Brightness brightness) {
    return brightness == Brightness.dark
        ? ShimmerConfig.dark()
        : const ShimmerConfig();
  }
}

/// Shimmer effect widget that animates its children
class Shimmer extends StatefulWidget {
  final Widget child;
  final ShimmerConfig config;
  final bool enabled;

  const Shimmer({
    super.key,
    required this.child,
    this.config = const ShimmerConfig(),
    this.enabled = true,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.config.duration,
    );
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: [
                widget.config.baseColor,
                widget.config.highlightColor,
                widget.config.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// A skeleton placeholder box
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsets? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.margin,
  });

  /// Creates a circular skeleton (for avatars)
  factory SkeletonBox.circle({
    Key? key,
    double size = 40,
    EdgeInsets? margin,
  }) {
    return SkeletonBox(
      key: key,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      margin: margin,
    );
  }

  /// Creates a rounded rectangle skeleton
  factory SkeletonBox.rounded({
    Key? key,
    double? width,
    double height = 16,
    double radius = 4,
    EdgeInsets? margin,
  }) {
    return SkeletonBox(
      key: key,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      ),
    );
  }
}

/// Skeleton for a list item row
class SkeletonListItem extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final int titleLines;
  final int subtitleLines;
  final double? leadingSize;
  final EdgeInsets padding;

  const SkeletonListItem({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.titleLines = 1,
    this.subtitleLines = 1,
    this.leadingSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer(
      config: ShimmerConfig.fromBrightness(isDark ? Brightness.dark : Brightness.light),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (hasLeading) ...[
              SkeletonBox.circle(size: leadingSize ?? 40),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < titleLines; i++) ...[
                    SkeletonBox.rounded(
                      width: i == 0 ? null : 150,
                      height: 16,
                    ),
                    if (i < titleLines - 1) const SizedBox(height: 4),
                  ],
                  if (subtitleLines > 0) ...[
                    const SizedBox(height: 8),
                    for (int i = 0; i < subtitleLines; i++) ...[
                      SkeletonBox.rounded(
                        width: i == subtitleLines - 1 ? 100 : null,
                        height: 12,
                      ),
                      if (i < subtitleLines - 1) const SizedBox(height: 4),
                    ],
                  ],
                ],
              ),
            ),
            if (hasTrailing) ...[
              const SizedBox(width: 16),
              const SkeletonBox(width: 60, height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a card layout
class SkeletonCard extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Widget? child;

  const SkeletonCard({
    super.key,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer(
      config: ShimmerConfig.fromBrightness(isDark ? Brightness.dark : Brightness.light),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: child ??
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 20, width: 150),
                SizedBox(height: 12),
                SkeletonBox(height: 14),
                SizedBox(height: 8),
                SkeletonBox(height: 14, width: 200),
              ],
            ),
      ),
    );
  }
}

/// Skeleton for a table row
class SkeletonTableRow extends StatelessWidget {
  final int columnCount;
  final double rowHeight;
  final List<double>? columnWidths;

  const SkeletonTableRow({
    super.key,
    this.columnCount = 4,
    this.rowHeight = 48,
    this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer(
      config: ShimmerConfig.fromBrightness(isDark ? Brightness.dark : Brightness.light),
      child: Container(
        height: rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
        child: Row(
          children: List.generate(columnCount, (index) {
            final width = columnWidths != null && index < columnWidths!.length
                ? columnWidths![index]
                : null;
            return Expanded(
              flex: width != null ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SkeletonBox.rounded(
                  width: width,
                  height: 16,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Builder that creates skeleton loading lists
class SkeletonListBuilder extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;

  const SkeletonListBuilder({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  /// Create a list of skeleton list items
  factory SkeletonListBuilder.listItems({
    Key? key,
    int itemCount = 5,
    bool hasLeading = true,
    bool hasTrailing = false,
    bool shrinkWrap = false,
    EdgeInsets? padding,
  }) {
    return SkeletonListBuilder(
      key: key,
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemBuilder: (context, index) => SkeletonListItem(
        hasLeading: hasLeading,
        hasTrailing: hasTrailing,
      ),
    );
  }

  /// Create a list of skeleton cards
  factory SkeletonListBuilder.cards({
    Key? key,
    int itemCount = 3,
    bool shrinkWrap = false,
    EdgeInsets? padding,
  }) {
    return SkeletonListBuilder(
      key: key,
      itemCount: itemCount,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }

  /// Create a skeleton table
  factory SkeletonListBuilder.table({
    Key? key,
    int rowCount = 5,
    int columnCount = 4,
    bool shrinkWrap = false,
    EdgeInsets? padding,
  }) {
    return SkeletonListBuilder(
      key: key,
      itemCount: rowCount,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemBuilder: (context, index) => SkeletonTableRow(
        columnCount: columnCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Widget that shows skeleton while loading, then content when ready
class SkeletonLoader extends StatelessWidget {
  final bool isLoading;
  final Widget skeleton;
  final Widget child;
  final Duration fadeDuration;

  const SkeletonLoader({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.child,
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: fadeDuration,
      child: isLoading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
