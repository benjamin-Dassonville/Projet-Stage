import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TeamPage extends StatelessWidget {
  final String teamId;

  const TeamPage({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEAM')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // TODO: team page ici
            context.go('/');
          },
          child: Text('TEAM $teamId'),
        ),
      ),
    );
  }
}