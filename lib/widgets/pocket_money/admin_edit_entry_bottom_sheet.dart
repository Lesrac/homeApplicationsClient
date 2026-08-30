import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminEditEntryBottomSheet extends StatefulWidget {
  final DateTime day;
  final int initialAmount;
  final int userId;
  final Future<void> Function(int amount, DateTime day, int userId) onSave;

  const AdminEditEntryBottomSheet({
    super.key,
    required this.day,
    required this.initialAmount,
    required this.userId,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required int initialAmount,
    required int userId,
    required Future<void> Function(int amount, DateTime day, int userId) onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return AdminEditEntryBottomSheet(
          day: day,
          initialAmount: initialAmount,
          userId: userId,
          onSave: onSave,
        );
      },
    );
  }

  @override
  State<AdminEditEntryBottomSheet> createState() =>
      _AdminEditEntryBottomSheetState();
}

class _AdminEditEntryBottomSheetState
    extends State<AdminEditEntryBottomSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmount > 0 ? widget.initialAmount.toString() : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Date: ${DateFormat('yyyy-MM-dd').format(widget.day)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(_controller.text.trim()) ?? 0;
                    Navigator.of(context).pop();
                    await widget.onSave(amount, widget.day, widget.userId);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
