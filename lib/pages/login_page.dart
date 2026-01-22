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
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: Icon(icon),
          label: Text(label),
          onPressed: () async {
            // ✅ AuthState exposes devLogin(role: ...) in this project.
            await authState.devLogin(role: role);
            if (context.mounted) context.go('/');
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Connexion'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choisis un rôle (dev)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),

                    LayoutBuilder(
                      builder: (context, c) {
                        final isWide = c.maxWidth >= 520;

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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}