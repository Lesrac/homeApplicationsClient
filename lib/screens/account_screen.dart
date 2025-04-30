import 'package:flutter/material.dart';
import 'package:homeApplications/models/credentials.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../helper/credentials_manager.dart';
import '../helper/headers.dart';

class AccountScreen extends StatefulWidget {
  final Credentials credentials;

  const AccountScreen({super.key, required this.credentials});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    final newPassword = _passwordController.text;
    if (newPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Password cannot be empty.';
        _isLoading = false;
      });
      return;
    }

    try {
      final url = Uri.parse('http://${widget.credentials.backendAddress}/user');
      final response = await http.patch(
        url,
        headers: HeadersHelper.getHeaders(widget.credentials),
        body: jsonEncode({
          'ID': widget.credentials.id,
          'Name': widget.credentials.username,
          'Access': widget.credentials.admin ? 'Admin' : 'User',
          'Password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'Password updated successfully.';
        });

        // Update the locally stored credentials
        final updatedCredentials = Credentials(
          username: widget.credentials.username,
          password: newPassword,
          backendAddress: widget.credentials.backendAddress,
          admin: widget.credentials.admin,
          id: widget.credentials.id,
        );
        await CredentialsManager.saveCredentials(updatedCredentials);

        // Update in-memory credentials
        setState(() {
          widget.credentials.password = newPassword;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to update password. Please try again.';
        });
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
      appBar: AppBar(title: const Text('Admin Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Username: ${widget.credentials.username}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (widget.credentials.admin)
              Text('Admin', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
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
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            if (_successMessage.isNotEmpty)
              Text(
                _successMessage,
                style: const TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}
