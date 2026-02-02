import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper widget to render text with clickable links
class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle? linkStyle;

  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    this.linkStyle,
  });

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>\[\]{}|\\^`"]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final matches = _urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(text, style: style);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the link
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: style));
      }

      // Add the clickable link
      final url = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _launchUrl(url),
            child: Text(
              url,
              style: linkStyle ??
                  style.copyWith(
                    color: Colors.lightBlue,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.lightBlue,
                  ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text after last link
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
