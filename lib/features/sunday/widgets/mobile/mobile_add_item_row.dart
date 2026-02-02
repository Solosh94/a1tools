/// Mobile Add Item Row Widget
/// Simple inline row for adding new items on mobile
library;

import 'package:flutter/material.dart';
import '../../../../app_theme.dart';

class MobileAddItemRow extends StatefulWidget {
  final Color groupColor;
  final Function(String name) onAdd;

  const MobileAddItemRow({
    super.key,
    required this.groupColor,
    required this.onAdd,
  });

  @override
  State<MobileAddItemRow> createState() => _MobileAddItemRowState();
}

class _MobileAddItemRowState extends State<MobileAddItemRow> {
  bool _isEditing = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      widget.onAdd(name);
      _controller.clear();
    }
    setState(() => _isEditing = false);
  }

  void _cancel() {
    _controller.clear();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    if (_isEditing) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: borderColor),
            left: BorderSide(color: widget.groupColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Item name...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: _cancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: Colors.grey,
            ),
            IconButton(
              icon: const Icon(Icons.check, size: 20),
              onPressed: _submit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: AppColors.accent,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _startEditing,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.5),
          border: Border(
            bottom: BorderSide(color: borderColor),
            left: BorderSide(color: widget.groupColor.withValues(alpha: 0.5), width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              Icons.add,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(
              'Add item',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
