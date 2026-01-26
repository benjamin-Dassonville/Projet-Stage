import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../auth/app_role.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget roleButton({
      required IconData icon,
      required String label,
      required AppRole role,
    }) {
      return FilledButton.icon(
        onPressed: () async {
          // AuthState exposes devLogin(role: ...) in this project.
          await authState.devLogin(role: role);
          if (context.mounted) context.go('/');
        },
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Connexion'),
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
                              Icons.shield_outlined,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EPI Control',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Choisis un rôle pour la démo",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Responsive :
                      // - PC / large : 3 boutons alignés et bien espacés
                      // - Mobile : un sous l'autre
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 520;

                          if (isWide) {
                            return Row(
                              children: [
                                Expanded(
                                  child: roleButton(
                                    icon: Icons.badge_outlined,
                                    label: 'Chef',
                                    role: AppRole.chef,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: roleButton(
                                    icon: Icons.admin_panel_settings_outlined,
                                    label: 'Admin',
                                    role: AppRole.admin,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: roleButton(
                                    icon: Icons.apartment_outlined,
                                    label: 'Direction',
                                    role: AppRole.direction,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              roleButton(
                                icon: Icons.badge_outlined,
                                label: 'Chef',
                                role: AppRole.chef,
                              ),
                              const SizedBox(height: 12),
                              roleButton(
                                icon: Icons.admin_panel_settings_outlined,
                                label: 'Admin',
                                role: AppRole.admin,
                              ),
                              const SizedBox(height: 12),
                              roleButton(
                                icon: Icons.apartment_outlined,
                                label: 'Direction',
                                role: AppRole.direction,
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 14),
                      Text(
                        "Astuce : tu peux changer de rôle à tout moment via la déconnexion.",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
