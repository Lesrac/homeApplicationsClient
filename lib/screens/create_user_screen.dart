import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../helper/headers.dart';
import '../models/credentials.dart';
import '../models/user.dart';

class CreateUserScreen extends StatefulWidget {
  final Credentials credentials;

  const CreateUserScreen({super.key, required this.credentials});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isAdmin = false;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  Future<void> _createUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username and password cannot be empty.';
        _isLoading = false;
      });
      return;
    }
    try {
      final url = Uri.parse('http://${widget.credentials.backendAddress}/user');
      final response = await http.post(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
        body: jsonEncode(
          User(password, id: null, name: username, access: _isAdmin ? 'admin' : 'user'),
        ),
      );
      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Failed to create user: ${response.body}';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create User')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Create a new user'),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: _obscurePassword,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _isAdmin,
                  onChanged: (bool? value) {
                    setState(() {
                      _isAdmin = value ?? false;
                    });
                  },
                ),
                const Text('Admin'),
              ],
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            if (_successMessage.isNotEmpty)
              Text(
                _successMessage,
                style: const TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _createUser,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create User'),
            ),
          ],
        ),
      ),
    );
  }
}
