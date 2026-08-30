import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddEntryDialog extends StatefulWidget {
  final Future<void> Function(int amount, DateTime date) onAdd;

  const AddEntryDialog({super.key, required this.onAdd});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(int amount, DateTime date) onAdd,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AddEntryDialog(onAdd: onAdd),
    );
  }

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  int _amount = 0;
  DateTime? _date;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Entry'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Amount'),
            onChanged: (value) {
              _amount = int.tryParse(value) ?? 0;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _date != null
                      ? DateFormat('yyyy-MM-dd').format(_date!)
                      : 'No date selected',
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _date ?? DateTime.now(),
                    firstDate: DateTime(2010),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _date = pickedDate;
                    });
                  }
                },
                child: const Text('Select Date'),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Add'),
          onPressed: () async {
            final selectedDate = _date ?? DateTime.now();
            Navigator.of(context).pop();
            await widget.onAdd(_amount, selectedDate);
          },
        ),
      ],
    );
  }
}
