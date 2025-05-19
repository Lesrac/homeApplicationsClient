import 'package:flutter/material.dart';
import 'package:homeApplications/screens/account_screen.dart';
import 'package:homeApplications/screens/create_user_screen.dart';
import 'package:homeApplications/screens/credentials_input_screen.dart';
import 'audio_screen.dart';
import 'pocket_money_screen.dart';
import 'package:homeApplications/models/credentials.dart';

class MainScreen extends StatelessWidget {
  final Credentials credentials;
  final double boxHeight = 4;

  const MainScreen({super.key, required this.credentials});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Screen'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
          // Adjust for tile size
          children: [
            // Pocket Money Tile
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              PocketMoneyScreen(credentials: credentials),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.money), // Money icon
                    SizedBox(height: boxHeight),
                    Text('Pocket Money', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            if (credentials.admin)
              Card(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                CreateUserScreen(credentials: credentials),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add), // Money icon
                      SizedBox(height: boxHeight),
                      Text('Create User', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CredentialsInputScreen(),
                    ),
                  );
                  //  Navigator.pushReplacementNamed(context, "/credentials");
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings), // Settings icon
                    SizedBox(height: boxHeight),
                    Text('Server Settings', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AccountScreen(credentials: credentials),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.manage_accounts), // Settings icon
                    SizedBox(height: boxHeight),
                    Text('Account Settings', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AudioScreen(credentials: credentials),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note), // Settings icon
                    SizedBox(height: boxHeight),
                    Text('Audio', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
