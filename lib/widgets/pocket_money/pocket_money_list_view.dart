import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pocket_money_entry.dart';

class PocketMoneyListView extends StatelessWidget {
  final bool isAdmin;
  final bool hasSelectedUser;
  final Widget? userSelector;
  final List<PocketMoneyEntry> entries;
  final int? targetUserId;
  final VoidCallback? onAddEntryPressed;
  final void Function(PocketMoneyEntry entry)? onToggleConfirm;

  const PocketMoneyListView({
    super.key,
    required this.isAdmin,
    required this.hasSelectedUser,
    this.userSelector,
    required this.entries,
    required this.targetUserId,
    this.onAddEntryPressed,
    this.onToggleConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      return Column(
        children: [
          ?userSelector,
          ElevatedButton(
            onPressed: hasSelectedUser ? onAddEntryPressed : null,
            child: const Text('Add New Entry'),
          ),
          Expanded(
            child: _buildEntriesList(
              entries: entries
                  .where((element) => element.userId == targetUserId)
                  .toList(),
              isAdmin: true,
            ),
          ),
        ],
      );
    }

    return _buildEntriesList(
      entries: entries
          .where((element) => element.userId == targetUserId)
          .toList(),
      isAdmin: false,
    );
  }

  Widget _buildEntriesList({
    required List<PocketMoneyEntry> entries,
    required bool isAdmin,
  }) {
    final sortedEntries = List<PocketMoneyEntry>.from(entries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];

        if (isAdmin) {
          return ListTile(
            title: Text('Amount: ${entry.amount}'),
            subtitle: Text(
              'Date: ${DateFormat('yyyy-MM-dd').format(entry.date)}',
            ),
            trailing: Icon(
              entry.confirmed ? Icons.check : Icons.close,
              color: entry.confirmed ? Colors.green : Colors.red,
            ),
          );
        }

        return ListTile(
          title: Text('Amount: ${entry.amount}'),
          subtitle: Text(
            'Date: ${DateFormat('yyyy-MM-dd').format(entry.date)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                entry.confirmed ? Icons.check : Icons.close,
                color: entry.confirmed ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onToggleConfirm != null
                    ? () => onToggleConfirm!(entry)
                    : null,
                child: Text(
                  entry.confirmed ? 'Mark as Not Received' : 'Mark as Received',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
