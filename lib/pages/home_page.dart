import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../app_state.dart';
import '../auth/app_role.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _openTeamPicker(BuildContext context) async {
    final api = ApiClient();

    List<Map<String, dynamic>> teams;
    try {
      final res = await api.dio.get('/teams-meta');
      teams = (res.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement équipes: $e")),
      );
      return;
    }

    // Optionnel: mettre UNASSIGNED à la fin
    teams.sort((a, b) {
      final aId = (a['id'] ?? '').toString();
      final bId = (b['id'] ?? '').toString();
      if (aId == 'UNASSIGNED') return 1;
      if (bId == 'UNASSIGNED') return -1;
      final an = (a['name'] ?? '').toString();
      final bn = (b['name'] ?? '').toString();
      return an.compareTo(bn);
    });

    if (!context.mounted) return;

    final selectedTeamId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: true,
      builder: (sheetContext) {
        final searchCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = searchCtrl.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? teams
                : teams.where((t) {
                    final id = (t['id'] ?? '').toString().toLowerCase();
                    final name = (t['name'] ?? '').toString().toLowerCase();
                    return id.contains(q) || name.contains(q);
                  }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Choisir une équipe",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: "Fermer",
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      hintText: "Rechercher (nom / id)…",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchCtrl.clear();
                                setLocal(() {});
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text("Aucune équipe"),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              final id = (t['id'] ?? '').toString();
                              final name = (t['name'] ?? '').toString();
                              final title = name.isEmpty ? id : name;

                              return ListTile(
                                title: Text(title),
                                subtitle: Text("id: $id"),
                                onTap: () => Navigator.pop(sheetContext, id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedTeamId == null || selectedTeamId.isEmpty) return;
    if (!context.mounted) return;

    context.push('/teams/$selectedTeamId');
  }

  @override
  Widget build(BuildContext context) {
    final role = authState.role;

    // Boutons visibles selon rôle (côté HOME seulement, le router reste la sécurité réelle)
    final canOpenTeam = role == AppRole.chef; // équipe (contrôle EPI) : chef uniquement
    final canControlTeams = role != null; // contrôle équipes : chef + admin + direction
    final canDashboard = role == AppRole.admin; // dashboard : admin uniquement
    final canManageRoles = role == AppRole.chef || role == AppRole.direction;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Accueil'),
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
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenue, ${authState.displayName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rôle : ${role?.label ?? 'Non connecté'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;

                          final buttons = <Widget>[
                            if (canOpenTeam)
                              FilledButton.icon(
                                onPressed: () => _openTeamPicker(context),
                                icon: const Icon(Icons.groups_outlined),
                                label: const Text('Ouvrir équipe'),
                              ),
                            if (canManageRoles)
                              FilledButton.tonalIcon(
                                onPressed: () => context.push('/roles'),
                                icon: const Icon(Icons.rule_folder_outlined),
                                label: const Text('Rôles & équipements'),
                              ),
                            if (canControlTeams)
                              OutlinedButton.icon(
                                onPressed: () => context.push('/control-teams'),
                                icon: const Icon(Icons.manage_accounts_outlined),
                                label: const Text('Contrôle équipe'),
                              ),
                            if (canDashboard)
                              FilledButton.tonalIcon(
                                onPressed: () => context.push('/dashboard'),
                                icon: const Icon(Icons.analytics_outlined),
                                label: const Text('Dashboard'),
                              ),
                          ];

                          if (buttons.isEmpty) {
                            return Text(
                              "Aucune action disponible pour ce rôle.",
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }

                          if (isWide) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < buttons.length; i++) ...[
                                  SizedBox(
                                    width: 220,
                                    child: buttons[i],
                                  ),
                                  if (i != buttons.length - 1) const SizedBox(width: 12),
                                ],
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0; i < buttons.length; i++) ...[
                                buttons[i],
                                if (i != buttons.length - 1) const SizedBox(height: 12),
                              ],
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
      ),
    );
  }
}
