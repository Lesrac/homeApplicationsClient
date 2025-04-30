import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:homeApplications/models/user.dart';
import 'package:homeApplications/models/credentials.dart';

import '../helper/credentials_manager.dart';

class CredentialsInputScreen extends StatefulWidget {
  const CredentialsInputScreen({super.key});

  @override
  State<CredentialsInputScreen> createState() => _CredentialsInputScreenState();
}

class _CredentialsInputScreenState extends State<CredentialsInputScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _backendAddressController =
      TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final credentials = await CredentialsManager.loadCredentials();
    if (credentials != null) {
      setState(() {
        _usernameController.text = credentials.username;
        _passwordController.text = credentials.password;
        _backendAddressController.text = credentials.backendAddress;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _backendAddressController.dispose();
    super.dispose();
  }

  void _submitCredentials() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final backendAddress = _backendAddressController.text;
      final url = Uri.parse('http://$backendAddress/login');
      final String basicAuth =
          'Basic ${base64Encode(utf8.encode('${_usernameController.text}:${_passwordController.text}'))}';

      final response = await http.get(
        url,
        headers: {
          HttpHeaders.authorizationHeader: basicAuth,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Invalid credentials';
        });
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to connect to server.');
      }
      final responseUser = User.fromJson(jsonDecode(response.body));

      final credentials = Credentials(
        username: _usernameController.text,
        password: _passwordController.text,
        backendAddress: backendAddress,
        admin: responseUser.isAdmin,
        id: responseUser.id!,
      );
      await CredentialsManager.saveCredentials(credentials);
      // ignore: use_build_context_synchronously

      Navigator.pushReplacementNamed(context, "/main", arguments: credentials);
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to connect to server: $e';
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
      appBar: AppBar(title: const Text('Enter Credentials')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _backendAddressController,
              decoration: const InputDecoration(labelText: 'Backend Address'),
            ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
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
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitCredentials,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class CredentialsChecker extends StatefulWidget {
  const CredentialsChecker({super.key});

  @override
  State<StatefulWidget> createState() => _CredentialsCheckerState();
}

class _CredentialsCheckerState extends State<CredentialsChecker> {
  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  void _checkCredentials() async {
    final BuildContext currentContext = context;
    final credentials = await CredentialsManager.loadCredentials();
    if (credentials == null) {
      _navigateToCredentialsInput(currentContext, credentials);
    } else {
      _navigateToMainApp(currentContext, credentials);
    }
  }

  void _navigateToCredentialsInput(
    BuildContext context,
    Credentials? credentials,
  ) {
    Navigator.of(
      context,
    ).pushReplacementNamed("/credentials", arguments: credentials);
  }

  void _navigateToMainApp(BuildContext context, Credentials credentials) {
    Navigator.of(context).pushReplacementNamed("/main", arguments: credentials);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
