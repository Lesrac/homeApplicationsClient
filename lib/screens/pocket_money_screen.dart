import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:homeApplications/models/user.dart';
import 'package:homeApplications/models/pocket_money_entry.dart';
import 'package:homeApplications/models/credentials.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCredentials().then((loadedCredentials) {
      if (loadedCredentials != null) {
        if (!loadedCredentials.admin) {
          _selectedUserId = loadedCredentials.id; // Set for non-admin users
        }
        if (loadedCredentials.admin) {
          _loadUsers(
            loadedCredentials,
          ).then((value) => _loadInitialData(loadedCredentials));
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

  Future<void> _addEntryToBackend(
    int amount,
    DateTime date,
    int userId,
  ) async {
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
        'http://${widget.credentials.backendAddress}/pocketMoney/acknowledgeAction',
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
              ElevatedButton(
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2010),
                    lastDate: DateTime(2101),
                  );
                  setState(() {
                    if (pickedDate != null) {
                      date = pickedDate;
                    }
                  });
                },
                child: Text("Select Date"),
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
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadInitialData(widget.credentials);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          widget.credentials.admin
              ? Column(
                children: [
                  DropdownButton<String>(
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
                    items:
                        _users.map<DropdownMenuItem<String>>((User user) {
                          return DropdownMenuItem<String>(
                            value: user.name,
                            child: Text(user.name),
                          );
                        }).toList(),
                  ),
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
                    trailing: ElevatedButton(
                      onPressed: () {
                        _confirmEntry(entry.id, !entry.confirmed);
                        setState(() {
                          entry.confirmed = !entry.confirmed;
                        });
                      },
                      child: Text(entry.confirmed ? 'Refute' : 'Confirm'),
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
}
