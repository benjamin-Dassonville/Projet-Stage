import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('dashboard')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // TODO: dashboard a faire ici 
            context.go('/');
          },
          child: const Text('dash'),
        ),
      ),
    );
  }
}