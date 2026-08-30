import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helper/credentials_manager.dart';
import '../models/credentials.dart';
import '../models/pocket_money_entry.dart';
import '../models/user.dart';
import '../services/pocket_money_service.dart';
import '../widgets/pocket_money/add_entry_dialog.dart';
import '../widgets/pocket_money/admin_edit_entry_bottom_sheet.dart';
import '../widgets/pocket_money/pocket_money_calendar_view.dart';
import '../widgets/pocket_money/pocket_money_list_view.dart';
import '../widgets/pocket_money/user_selector_dropdown.dart';

class PocketMoneyScreen extends StatefulWidget {
  final Credentials credentials;
  final PocketMoneyService? service;

  const PocketMoneyScreen({
    super.key,
    required this.credentials,
    this.service,
  });

  @override
  State<PocketMoneyScreen> createState() => _PocketMoneyScreenState();
}

class _PocketMoneyScreenState extends State<PocketMoneyScreen> {
  late final PocketMoneyService _service;
  List<PocketMoneyEntry> _entries = [];
  List<User> _users = [];
  int? _selectedUserId;
  String _errorMessage = '';

  bool _showCalendar = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PocketMoneyEntry>> _events = {};

  bool get _hasSelectedUser =>
      _selectedUserId != null && _selectedUserId != -1;

  DateTime _normalizeDate(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PocketMoneyService();
    _showCalendar = true;
    _initializeData();
  }

  Future<void> _initializeData() async {
    final credentials = await _resolveCredentials();
    if (!mounted) return;
    if (credentials == null) {
      Navigator.of(context).pushReplacementNamed('/credentials');
      return;
    }

    if (!credentials.admin) {
      _selectedUserId = credentials.id;
      await _loadInitialData(credentials);
    } else {
      await _loadUsers(credentials);
      if (mounted) {
        await _loadInitialData(credentials);
      }
    }
  }

  Future<Credentials?> _resolveCredentials() async {
    if (widget.credentials.username.isNotEmpty) {
      return widget.credentials;
    }
    try {
      return await CredentialsManager.loadCredentials();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading credentials: $e';
      });
      return null;
    }
  }

  Future<void> _loadUsers(Credentials credentials) async {
    try {
      final users = await _service.fetchUsers(credentials);
      if (!mounted) return;
      setState(() {
        _users = users;
        _selectedUserId = credentials.admin ? null : credentials.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading users: $e';
      });
    }
  }

  Future<void> _loadInitialData(Credentials credentials) async {
    if (credentials.admin && !_hasSelectedUser) {
      return;
    }
    final userIdToLoad =
        credentials.admin ? _selectedUserId! : credentials.id;

    try {
      final entries = await _service.fetchEntries(credentials, userIdToLoad);
      if (!mounted) return;
      setState(() {
        _entries = entries;
      });
      _buildEventsMap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading initial data: $e';
      });
    }
  }

  void _buildEventsMap() {
    final Map<DateTime, List<PocketMoneyEntry>> map = {};
    for (final e in _entries) {
      final key = _normalizeDate(e.date);
      map.putIfAbsent(key, () => []).add(e);
    }
    setState(() {
      _events = map;
    });
  }

  void _addLocalEntry(int amount, DateTime date, int userId) {
    setState(() {
      final normalized = _normalizeDate(date);
      final index = _entries.indexWhere(
        (e) => _normalizeDate(e.date) == normalized && e.userId == userId,
      );
      if (index != -1) {
        _entries[index].amount = amount;
      } else {
        _entries.add(
          PocketMoneyEntry(amount: amount, date: date, userId: userId),
        );
      }
      _entries.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _addEntryToBackend(int amount, DateTime date, int userId) async {
    try {
      await _service.addEntry(
        credentials: widget.credentials,
        userId: userId,
        amount: amount,
        date: date,
      );
      if (!mounted) return;
      _addLocalEntry(amount, date, userId);
      _buildEventsMap();
      setState(() {
        _errorMessage = '';
      });
      await _loadInitialData(widget.credentials);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to add entry: $e';
      });
    }
  }

  Future<void> _confirmEntry(int? id, bool confirm) async {
    try {
      await _service.confirmEntry(
        credentials: widget.credentials,
        id: id,
        confirm: confirm,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to confirm entry: $e';
      });
    }
  }

  void _onDayTapped(DateTime day) {
    if (widget.credentials.admin && !_hasSelectedUser) {
      setState(() {
        _errorMessage = 'Please select a user first.';
      });
      return;
    }

    final normalized = _normalizeDate(day);
    final entries = _events[normalized] ?? [];

    if (widget.credentials.admin) {
      final initialAmount = entries.isNotEmpty ? entries.first.amount : 0;
      AdminEditEntryBottomSheet.show(
        context,
        day: day,
        initialAmount: initialAmount,
        userId: _selectedUserId!,
        onSave: (amount, date, userId) async {
          await _addEntryToBackend(amount, date, userId);
        },
      );
    } else {
      if (entries.isEmpty) {
        showModalBottomSheet<void>(
          context: context,
          builder: (bottomSheetContext) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Text(
                    'No planned amount for this day. Please contact an admin to set an amount.',
                  ),
                ],
              ),
            );
          },
        );
        return;
      }

      final entry = entries.first;
      showModalBottomSheet<void>(
        context: context,
        builder: (bottomSheetContext) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(day)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Amount: ${entry.amount}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _confirmEntry(entry.id, !entry.confirmed);
                    setState(() {
                      entry.confirmed = !entry.confirmed;
                      _buildEventsMap();
                    });
                  },
                  child: Text(
                    entry.confirmed
                        ? 'Mark as Not Received'
                        : 'Mark as Received',
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildUserSelector() {
    return UserSelectorDropdown(
      users: _users,
      selectedUserId: _selectedUserId,
      onChanged: (id) {
        setState(() {
          _entries = [];
          _errorMessage = '';
          _selectedUserId = id;
        });
        if (_selectedUserId != null) {
          _loadInitialData(widget.credentials);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Money Entries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(
                '/credentials',
                arguments: widget.credentials,
              );
            },
          ),
          IconButton(
            icon: Icon(_showCalendar ? Icons.list : Icons.calendar_today),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadInitialData(widget.credentials);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_showCalendar)
            Positioned.fill(
              child: PocketMoneyCalendarView(
                isAdmin: widget.credentials.admin,
                hasSelectedUser: _hasSelectedUser,
                userSelector:
                    widget.credentials.admin ? _buildUserSelector() : null,
                events: _events,
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  _onDayTapped(selected);
                },
              ),
            )
          else
            PocketMoneyListView(
              isAdmin: widget.credentials.admin,
              hasSelectedUser: _hasSelectedUser,
              userSelector:
                  widget.credentials.admin ? _buildUserSelector() : null,
              entries: _entries,
              targetUserId: widget.credentials.admin
                  ? _selectedUserId
                  : widget.credentials.id,
              onAddEntryPressed: () {
                AddEntryDialog.show(
                  context,
                  onAdd: (amount, date) =>
                      _addEntryToBackend(amount, date, _selectedUserId!),
                );
              },
              onToggleConfirm: (entry) async {
                await _confirmEntry(entry.id, !entry.confirmed);
                setState(() {
                  entry.confirmed = !entry.confirmed;
                });
              },
            ),
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 8,
              left: 32,
              right: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha((0.6 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
