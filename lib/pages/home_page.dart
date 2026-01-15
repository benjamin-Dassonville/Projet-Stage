import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../auth/app_role.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final role = authState.role;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await authState.logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenue, ${authState.displayName}'),
            const SizedBox(height: 8),
            Text('Rôle: ${role?.label ?? 'Non connecté'}'),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/teams/1'),
                  child: const Text('Ouvrir équipe (démo)'),
                ),
                ElevatedButton(
                  onPressed: () => context.go('/workers/42/check'),
                  child: const Text('Contrôle travailleur (démo)'),
                ),
                if (role == AppRole.admin || role == AppRole.direction)
                  ElevatedButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Dashboard'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}