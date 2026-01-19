import 'package:flutter/material.dart';

class ForbiddenPage extends StatelessWidget {
  final String? message;
  const ForbiddenPage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès refusé')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message ?? "Vous n'avez pas les droits pour accéder à cette page."),
      ),
    );
  }
}