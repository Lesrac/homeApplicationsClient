import 'package:flutter/material.dart';
import "package:homeApplications/screens/account_screen.dart";
import 'package:homeApplications/screens/audio_screen.dart';
import 'package:homeApplications/screens/create_user_screen.dart';

import 'helper/credentials_manager.dart';
import 'screens/credentials_input_screen.dart';
import 'package:homeApplications/screens/main_screen.dart';
import 'package:homeApplications/models/credentials.dart';
import 'services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(MyApp());
}

bool isConnectedToServer = false;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _home = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Applications',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/credentials': (context) => CredentialsInputScreen(),
        '/account':
            (context) => AccountScreen(
              credentials:
                  ModalRoute.of(context)!.settings.arguments as Credentials,
            ),
        '/main':
            (context) => MainScreen(
              credentials:
                  ModalRoute.of(context)!.settings.arguments as Credentials,
            ),
        '/user':
            (context) => CreateUserScreen(
              credentials:
                  ModalRoute.of(context)!.settings.arguments as Credentials,
            ),
        '/audio':
            (context) => AudioScreen(
              credentials:
                  ModalRoute.of(context)!.settings.arguments as Credentials,
            ),
      },

      home: _home,
    );
  }

  void _checkCredentials() async {
    final credentials = await CredentialsManager.loadCredentials();
    setState(() {
      if (credentials == null) {
        _home = const CredentialsChecker();
      } else {
        _home = MainScreen(credentials: credentials);
      }
    });
  }
}
