import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_state.dart';

class WaitingPage extends StatelessWidget {
  const WaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('En attente'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await authState.logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            child: Icon(
                              Icons.hourglass_top_outlined,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Compte non assigné',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Ton compte est bien connecté, mais il n’a pas encore de rôle.\n\n"
                        "Un admin ou la direction doit t’attribuer un rôle avant que tu puisses accéder à l’application.\n\n"
                        "Si rien ne se passe apres avoir appuié sur le bouton, c'est que le rôle n'est pas a jour.",
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await authState.refreshProfile();

                          if (!context.mounted) return;

                          if (authState.role != 'UNASSIGNED') {
                            context.go('/');
                          } else {
                            context.go('/waiting'); // revalidation propre
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Vérifier mon accès'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
