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
      // ❌ PAS de leading → PAS de flèche retour sur l’accueil
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Accueil'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await authState.logout();
              if (context.mounted) {
                context.go('/login'); // reset navigation
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue, ${authState.displayName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Rôle : ${role?.label ?? 'Non connecté'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // ✅ push → historique conservé → retour OK
                ElevatedButton(
                  onPressed: () => context.push('/teams/1'),
                  child: const Text('Ouvrir équipe (démo)'),
                ),

                // ⚠️ volontairement laissé pour test des droits
                ElevatedButton(
                  onPressed: () => context.push('/workers/42/check'),
                  child: const Text('Contrôle travailleur (démo)'),
                ),

                // ✅ Dashboard UNIQUEMENT admin + direction
                if (role == AppRole.admin || role == AppRole.direction)
                  ElevatedButton(
                    onPressed: () => context.push('/dashboard'),
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