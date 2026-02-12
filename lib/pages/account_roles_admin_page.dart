import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/app_role.dart';

class AccountRolesAdminPage extends StatefulWidget {
  const AccountRolesAdminPage({super.key});

  @override
  State<AccountRolesAdminPage> createState() => _AccountRolesAdminPageState();
}

class _AccountRolesAdminPageState extends State<AccountRolesAdminPage> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> pending = [];
  final Map<String, bool> saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final supa = Supabase.instance.client;

      final rows = await supa
          .from('profiles')
          .select('id, email, full_name, role, created_at')
          .eq('role', 'non_assigne')
          .order('created_at', ascending: true);

      setState(() {
        pending = (rows as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _label(Map<String, dynamic> p) {
    final name = (p['full_name'] ?? '').toString().trim();
    final email = (p['email'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    return (p['id'] ?? '').toString();
  }

  Future<bool> _confirmAssign({
    required String userLabel,
    required String roleLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer l’attribution'),
        content: Text(
          'Attribuer le rôle "$roleLabel" à :\n\n$userLabel\n\nTu confirmes ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _roleLabel(AppRole role) {
    return switch (role) {
      AppRole.chef => 'Chef',
      AppRole.admin => 'Admin',
      AppRole.direction => 'Direction',
      AppRole.nonAssigne => 'Non assigné',
    };
  }

  Future<void> _assignRole(String userId, AppRole role) async {
    setState(() => saving[userId] = true);

    try {
      final supa = Supabase.instance.client;

      // mapping DB
      final dbRole = switch (role) {
        AppRole.chef => 'chef',
        AppRole.admin => 'admin',
        AppRole.direction => 'direction',
        AppRole.nonAssigne => 'non_assigne',
      };

      await supa.from('profiles').update({'role': dbRole}).eq('id', userId);

      if (!mounted) return;

      setState(() {
        pending.removeWhere((x) => (x['id'] ?? '').toString() == userId);
        saving.remove(userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rôle attribué ✅ ($dbRole)')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving.remove(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur attribution: $e')),
      );
    }
  }

  Future<void> _confirmAndAssign(String userId, AppRole role, Map<String, dynamic> p) async {
    if (saving[userId] == true) return;

    final ok = await _confirmAssign(
      userLabel: _label(p),
      roleLabel: _roleLabel(role),
    );

    if (!ok) return;
    await _assignRole(userId, role);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attribution des rôles'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attribution des rôles'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attribution des rôles'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: pending.isEmpty
          ? const Center(child: Text('Aucun compte en attente ✅'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = pending[i];
                final id = (p['id'] ?? '').toString();
                final email = (p['email'] ?? '').toString();
                final isSaving = saving[id] == true;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _label(p),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(email),
                        ],
                        const SizedBox(height: 10),
                        if (isSaving)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _confirmAndAssign(id, AppRole.chef, p),
                                icon: const Icon(Icons.badge_outlined),
                                label: const Text('Chef'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _confirmAndAssign(id, AppRole.admin, p),
                                icon: const Icon(Icons.admin_panel_settings_outlined),
                                label: const Text('Admin'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _confirmAndAssign(id, AppRole.direction, p),
                                icon: const Icon(Icons.apartment_outlined),
                                label: const Text('Direction'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}