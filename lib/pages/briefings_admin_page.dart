import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BriefingsAdminPage extends StatelessWidget {
  const BriefingsAdminPage({super.key});

  Widget _card({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String route,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push(route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des briefings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            context: context,
            icon: Icons.library_books,
            title: 'Sujets de briefing',
            description: 'Créer et gérer les sujets disponibles pour les briefings.',
            route: '/briefings/admin/topics',
          ),
          const SizedBox(height: 12),
          _card(
            context: context,
            icon: Icons.event,
            title: 'Obligations par date',
            description: 'Rendre certains sujets obligatoires à une date précise.',
            route: '/briefings/admin/required-day',
          ),
          const SizedBox(height: 12),
          _card(
            context: context,
            icon: Icons.repeat,
            title: 'Règles récurrentes',
            description: 'Configurer des obligations automatiques (ex : chaque lundi).',
            route: '/briefings/admin/rules',
          ),
        ],
      ),
    );
  }
}