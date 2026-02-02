/// Text Cell Widget
/// Displays and edits text column values
library;

import 'package:flutter/material.dart';

class TextCell extends StatefulWidget {
  final String value;
  final Function(String) onChanged;

  const TextCell({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<TextCell> {
  bool _editing = false;
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        _save();
      }
    });
  }

  @override
  void didUpdateWidget(TextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_editing) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 12),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        onSubmitted: (_) => _save(),
      );
    }

    return InkWell(
      onTap: () {
        setState(() => _editing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          widget.value.isEmpty ? '-' : widget.value,
          style: TextStyle(
            fontSize: 12,
            color: widget.value.isEmpty
                ? Colors.grey.shade500
                : (isDark ? Colors.white70 : Colors.black87),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _save() {
    setState(() => _editing = false);
    if (_controller.text != widget.value) {
      widget.onChanged(_controller.text);
    }
  }
}
