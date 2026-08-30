import 'package:flutter/material.dart';
import '../../models/user.dart';

class UserSelectorDropdown extends StatelessWidget {
  final List<User> users;
  final int? selectedUserId;
  final ValueChanged<int?> onChanged;

  const UserSelectorDropdown({
    super.key,
    required this.users,
    required this.selectedUserId,
    required this.onChanged,
  });

  bool get _hasSelectedUser =>
      selectedUserId != null && selectedUserId != -1;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: users.isNotEmpty && _hasSelectedUser
          ? users
                .firstWhere(
                  (user) => user.id == selectedUserId,
                  orElse: () => users.first,
                )
                .name
          : null,
      hint: const Text('Select User'),
      onChanged: (String? newValue) {
        final selectedUser = users.firstWhere(
          (user) => user.name == newValue,
          orElse: () => users.first,
        );
        final id = selectedUser.id == -1 ? null : selectedUser.id;
        onChanged(id);
      },
      items: users.map<DropdownMenuItem<String>>((User user) {
        return DropdownMenuItem<String>(
          value: user.name,
          child: Text(user.name),
        );
      }).toList(),
    );
  }
}
