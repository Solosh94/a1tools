/// Board Header Widget
/// Shows column headers and controls
library;

import 'package:flutter/material.dart';
import '../models/sunday_models.dart';

class BoardHeader extends StatelessWidget {
  final SundayBoard board;
  final VoidCallback onAddColumn;
  final Function(List<int>) onColumnReorder;

  const BoardHeader({
    super.key,
    required this.board,
    required this.onAddColumn,
    required this.onColumnReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Board info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (board.description != null && board.description!.isNotEmpty)
                  Text(
                    board.description!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  '${board.itemCount} items',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Quick filters
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('Filter'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.sort, size: 18),
            label: const Text('Sort'),
          ),
        ],
      ),
    );
  }
}
