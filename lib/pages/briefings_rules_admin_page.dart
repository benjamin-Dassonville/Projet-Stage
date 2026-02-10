import 'package:flutter/material.dart';

class BriefingsRulesAdminPage extends StatelessWidget {
  const BriefingsRulesAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Règles récurrentes')),
      body: const Center(
        child: Text('À faire : gestion des règles récurrentes.'),
      ),
    );
  }
}