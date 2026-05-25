import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:homeApplications/models/user.dart';
import 'package:homeApplications/models/pocket_money_entry.dart';
import 'package:homeApplications/models/credentials.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helper/headers.dart';

class PocketMoneyScreen extends StatefulWidget {
  final Credentials credentials;

  const PocketMoneyScreen({super.key, required this.credentials});

  @override
  State<PocketMoneyScreen> createState() => _PocketMoneyScreenState();
}

class _PocketMoneyScreenState extends State<PocketMoneyScreen> {
  List<PocketMoneyEntry> _entries = [];
  List<User> _users = [];
  int? _selectedUserId;
  String _errorMessage = '';

  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PocketMoneyEntry>> _events = {};

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

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

  Widget _userSelector() {
    return DropdownButton<String>(
        value:
        _users.isNotEmpty && _selectedUserId != null
            ? _users
            .firstWhere(
              (user) => user.id == _selectedUserId,
          orElse: () => _users.first,
        )
            .name
            : null,
        hint: Text("Select User"),
        onChanged: (String? newValue) {
          setState(() {
            _entries = [];
            _errorMessage = '';

            _selectedUserId =
                _users
                    .firstWhere(
                      (user) => user.name == newValue,
                  orElse: () => _users.first,
                )
                    .id;
          });
          _loadInitialData(widget.credentials);
        },
        items: _users.map<DropdownMenuItem<String>>((User user) {
          return DropdownMenuItem<String>(
            value: user.name,
            child: Text(user.name),
          );
        }).toList(),
      );
  }

  @override
  void initState() {
    super.initState();
    _showCalendar = true;
    _loadCredentials().then((loadedCredentials) {
      // Guard against using the BuildContext after the widget is disposed.
      if (!mounted) return;
      if (loadedCredentials != null) {
        if (!loadedCredentials.admin) {
          _selectedUserId = loadedCredentials.id; // Set for non-admin users
        }
        if (loadedCredentials.admin) {
          _loadUsers(
            loadedCredentials,
          ).then((value) {
            if (!mounted) return;
            _loadInitialData(loadedCredentials);
          });
        } else {
          _loadInitialData(loadedCredentials);
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/credentials');
        return;
      }
    });
  }

  Future<Credentials?> _loadCredentials() async {
    if (widget.credentials.username != "") {
      return widget.credentials;
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/credentials.json');
      if (!await file.exists()) {
        return null;
      }
      final String content = await file.readAsString();
      final Map<String, dynamic> jsonMap = jsonDecode(content);
      return Credentials.fromJson(jsonMap);
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading credentials: $e";
      });
      return null;
    }
  }

  Future<void> _loadUsers(Credentials credentials) async {
    try {
      final url = Uri.parse(
        'http://${widget.credentials.backendAddress}/users',
      );

      final response = await http.get(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load users.');
      }
      setState(() {
        _users =
            [User(null, id: -1, name: 'Select User', access: 'user')]
                .followedBy(
              (jsonDecode(response.body) as List)
                  .map((userJson) => User.fromJson(userJson))
                  .toList()
                  .where((user) => !user.isAdmin)
                  .toList(),
            )
                .toList();
        _selectedUserId = _users.isNotEmpty ? null : null;
        if (!credentials.admin) {
          _selectedUserId = credentials.id;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading users: $e";
      });
    }
  }

  Future<void> _loadInitialData(Credentials credentials) async {
    if (credentials.admin && _selectedUserId == null) {
      return;
    }
    try {
      String userIdToLoad =
      _selectedUserId != null ? _selectedUserId.toString() : "";
      if (!credentials.admin) {
        userIdToLoad = credentials.id.toString();
      }
      final url = Uri.parse(
        'http://${credentials.backendAddress}/pocketMoney/$userIdToLoad',
      );
      final response = await http.get(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to load pocket money entries.');
      }
      setState(() {
        _entries =
            (jsonDecode(response.body) as List)
                .map((entryJson) => PocketMoneyEntry.fromJson(entryJson))
                .toList();
      });
      _buildEventsMap();
    } catch (e) {
      setState(() {
        _errorMessage = "Error loading initial data: $e";
      });
    }
  }

  void _addEntry(int amount, DateTime date, int userId) {
    setState(() {
      _entries.add(
        PocketMoneyEntry(amount: amount, date: date, userId: userId),
      );
      _entries.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _addEntryToBackend(int amount,
      DateTime date,
      int userId,) async {
    try {
      final url = Uri.parse(
        'http://${widget.credentials.backendAddress}/pocketMoney/addAction',
      );
      final response = await http.post(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
        body: jsonEncode({
          'userId': userId,
          'amount': amount,
          'date': date.toIso8601String(),
        }),
      );
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Failed to add entry: ${response.body}';
        });
      } else {
        _addEntry(amount, date, userId);
        // Rebuild calendar events map
        _buildEventsMap();
         setState(() {
           _errorMessage = '';
         });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add entry: $e';
      });
    }
  }

  Future<void> _confirmEntry(int? id, bool confirm) async {
    try {
      final url = Uri.parse(
        'http://${widget.credentials
            .backendAddress}/pocketMoney/acknowledgeAction',
      );
      final response = await http.post(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
        body: jsonEncode({'id': id, 'action': confirm ? 'confirm' : 'refute'}),
      );
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Failed to confirm entry: ${response.body}';
        });
      } else {
        setState(() {
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to confirm entry: $e';
      });
    }
  }

  void _showAddEntryDialog() {
    int amount = 0;
    DateTime? date;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setStateDialog) {
            return AlertDialog(
              title: Text('Add New Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(hintText: "Amount"),
                    onChanged: (value) {
                      amount = int.tryParse(value) ?? 0;
                    },
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          date != null
                              ? DateFormat('yyyy-MM-dd').format(date!)
                              : 'No date selected',
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2010),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            // Update the dialog-local state so the label updates immediately.
                            setStateDialog(() {
                              date = pickedDate;
                            });
                          }
                        },
                        child: Text("Select Date"),
                      ),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Add'),
                  onPressed: () {
                    date ??= DateTime.now();
                    _addEntryToBackend(amount, date!, _selectedUserId!);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pocket Money Entries'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
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
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadInitialData(widget.credentials);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Calendar overlay (shows above the list when toggled)
          if (_showCalendar)
            Positioned.fill(
              child: SafeArea(
                child: Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pocket Money Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            if (widget.credentials.admin)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: _userSelector()
                              ),
                            Row(children: [
                              Container(width:12,height:12,decoration:BoxDecoration(color:Colors.orange,shape:BoxShape.circle)),
                              SizedBox(width:6), Text('Planned'), SizedBox(width:12),
                              Container(width:12,height:12,decoration:BoxDecoration(color:Colors.green,shape:BoxShape.circle)),
                              SizedBox(width:6), Text('Received')
                            ])
                          ],
                        ),
                      ),
                      Expanded(
                        child: TableCalendar(
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                          },
                          firstDay: DateTime(2010, 1, 1),
                          lastDay: DateTime(2101, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay, day),
                          eventLoader: (day) => _events[_normalizeDate(day)] ?? [],
                          onDaySelected: (selected, focused) {
                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                            _onDayTapped(selected);
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isNotEmpty) {
                                final anyConfirmed = events.any((e) => (e as PocketMoneyEntry?)?.confirmed ?? false);
                                final color = anyConfirmed ? Colors.green : Colors.orange;
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // comment
          if (!_showCalendar)
            widget.credentials.admin
                ? Column(
            children: [
              _userSelector(),
              ElevatedButton(
                onPressed:
                _selectedUserId != null ? _showAddEntryDialog : null,
                child: Text('Add New Entry'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount:
                  _entries
                      .where(
                        (element) => element.userId == _selectedUserId,
                  )
                      .length,
                  itemBuilder: (context, index) {
                    List<PocketMoneyEntry> sortedEntries =
                    _entries
                        .where(
                          (element) =>
                      element.userId == _selectedUserId,
                    )
                        .toList()
                      ..sort(
                            (a, b) => b.date.compareTo(a.date),
                      ); // Sort by date descending

                    PocketMoneyEntry entry = sortedEntries[index];

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
                  },
                ),
              ),
            ],
          )
              : ListView.builder(
            itemCount:
            _entries
                .where(
                  (element) => element.userId == widget.credentials.id,
            )
                .length,
            itemBuilder: (context, index) {
              List<PocketMoneyEntry> sortedEntries =
              _entries
                  .where((element) => element.userId == _selectedUserId)
                  .toList()
                ..sort(
                      (a, b) => b.date.compareTo(a.date),
                ); // Sort by date descending

              PocketMoneyEntry entry = sortedEntries[index];
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
                            horizontal: 8, vertical: 4),
                        minimumSize: Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _confirmEntry(entry.id, !entry.confirmed);
                        setState(() {
                          entry.confirmed = !entry.confirmed;
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
          ),
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 8, // Add some margin from the top
              left: 32,
              right: 32,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha((0.6 * 255).toInt()),
                  // Semi-transparent red background
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.white, // White text for contrast
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

  void _onDayTapped(DateTime day) {
    final normalized = _normalizeDate(day);
    final entries = _events[normalized] ?? [];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (widget.credentials.admin) {
          int amount = entries.isNotEmpty ? entries.first.amount : 0;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date: ${DateFormat('yyyy-MM-dd').format(day)}', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Amount'),
                  controller: TextEditingController(text: amount.toString()),
                  onChanged: (v) => amount = int.tryParse(v) ?? 0,
                ),
                SizedBox(height:8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final userId = _selectedUserId ?? widget.credentials.id;
                        Navigator.of(context).pop();
                        await _addEntryToBackend(amount, day, userId);
                      },
                      child: Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No planned amount for this day. Please contact an admin to set an amount.'),
                ],
              ),
            );
          }
          final entry = entries.first;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Date: ${DateFormat('yyyy-MM-dd').format(day)}', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height:8),
                Text('Amount: ${entry.amount}'),
                SizedBox(height:8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _confirmEntry(entry.id, !entry.confirmed);
                    setState(() {
                      entry.confirmed = !entry.confirmed;
                      _buildEventsMap();
                    });
                  },
                  child: Text(entry.confirmed ? 'Mark as Not Received' : 'Mark as Received'),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
