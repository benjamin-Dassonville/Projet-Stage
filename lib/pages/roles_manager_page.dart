import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Roles & Equipment manager
/// - Accessible only to Chef + Direction (enforced by router.dart)
/// - UX: master-detail on wide screens, bottom sheet navigation on mobile
class RolesManagerPage extends StatefulWidget {
  const RolesManagerPage({super.key});

  @override
  State<RolesManagerPage> createState() => _RolesManagerPageState();
}

class _RolesManagerPageState extends State<RolesManagerPage> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> roles = [];
  Map<String, dynamic>? selectedRole;
  List<Map<String, dynamic>> roleEquipments = [];
  bool loadingEquip = false;

  final TextEditingController searchRoleCtrl = TextEditingController();
  final TextEditingController searchEquipCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoles();
    searchRoleCtrl.addListener(() => setState(() {}));
    searchEquipCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchRoleCtrl.dispose();
    searchEquipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoles({String? keepSelectedId}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/roles');
      final list = (res.data as List).cast<Map<String, dynamic>>();

      list.sort((a, b) {
        final an = (a['label'] ?? '').toString();
        final bn = (b['label'] ?? '').toString();
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });

      Map<String, dynamic>? sel;
      final wantedId = keepSelectedId ?? (selectedRole?['id']?.toString());
      if (wantedId != null) {
        sel = list.firstWhere(
          (r) => r['id']?.toString() == wantedId,
          orElse: () => list.isEmpty ? <String, dynamic>{} : list.first,
        );
        if (sel.isEmpty) sel = null;
      } else {
        sel = list.isEmpty ? null : list.first;
      }

      setState(() {
        roles = list;
        selectedRole = sel;
        loading = false;
      });

      if (sel != null) {
        await _loadRoleEquipments(sel['id'].toString());
      } else {
        setState(() => roleEquipments = []);
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadRoleEquipments(String roleId) async {
    setState(() {
      loadingEquip = true;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/roles/$roleId/equipment');
      final list = (res.data as List).cast<Map<String, dynamic>>();

      list.sort((a, b) {
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        roleEquipments = list;
        loadingEquip = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingEquip = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement équipements: $e')),
      );
    }
  }

  List<Map<String, dynamic>> get filteredRoles {
    final q = searchRoleCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return roles;
    return roles.where((r) {
      final id = (r['id'] ?? '').toString().toLowerCase();
      final label = (r['label'] ?? '').toString().toLowerCase();
      return id.contains(q) || label.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredEquipments {
    final q = searchEquipCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return roleEquipments;
    return roleEquipments.where((e) {
      final id = (e['id'] ?? '').toString().toLowerCase();
      final name = (e['name'] ?? '').toString().toLowerCase();
      return id.contains(q) || name.contains(q);
    }).toList();
  }

  Future<String?> _promptText({
    required String title,
    String? initial,
    required String label,
    String? hint,
    String okText = 'Enregistrer',
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');

    final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(labelText: label, hintText: hint),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(okText),
              ),
            ],
          ),
        ) ??
        false;

    final value = ctrl.text.trim();
    ctrl.dispose();

    if (!saved) return null;
    if (value.isEmpty) return null;
    return value;
  }

  Future<bool> _confirm({required String title, required String message}) async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _createRole() async {
    final label = await _promptText(
      title: 'Nouveau rôle',
      label: 'Nom du rôle',
      hint: 'ex: Débroussailleur',
      okText: 'Créer',
    );
    if (label == null) return;

    try {
      final api = ApiClient();
      final res = await api.dio.post('/roles', data: {'label': label});
      final created = (res.data as Map).cast<String, dynamic>();
      await _loadRoles(keepSelectedId: created['id']?.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rôle créé: ${created['label']}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création rôle: $e')),
      );
    }
  }

  Future<void> _renameRole(Map<String, dynamic> role) async {
    final id = role['id']?.toString();
    if (id == null || id.isEmpty) return;

    final newLabel = await _promptText(
      title: 'Renommer rôle',
      initial: (role['label'] ?? '').toString(),
      label: 'Nom',
      okText: 'Renommer',
    );
    if (newLabel == null) return;

    try {
      final api = ApiClient();
      await api.dio.patch('/roles/$id', data: {'label': newLabel});
      await _loadRoles(keepSelectedId: id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur renommage: $e')),
      );
    }
  }

  Future<void> _deleteRole(Map<String, dynamic> role) async {
    final id = role['id']?.toString();
    final label = (role['label'] ?? '').toString();
    if (id == null || id.isEmpty) return;

    final ok = await _confirm(
      title: 'Supprimer rôle',
      message: 'Supprimer "$label" ?\n\nLes associations équipements seront supprimées.',
    );
    if (!ok) return;

    try {
      final api = ApiClient();
      await api.dio.delete('/roles/$id');
      await _loadRoles(keepSelectedId: null);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Rôle supprimé: $label')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  Future<void> _openAddEquipmentSheet() async {
    final roleId = selectedRole?['id']?.toString();
    if (roleId == null || roleId.isEmpty) return;

    // charge la liste globale des équipements
    List<Map<String, dynamic>> all;
    try {
      final api = ApiClient();
      final res = await api.dio.get('/equipment');
      all = (res.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur chargement équipements: $e')));
      return;
    }

    // pour filtrer déjà assignés
    final assignedIds = roleEquipments.map((e) => e['id']?.toString()).toSet();

    if (!mounted) return;
    final selected = await showModalBottomSheet<_EquipPickResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: true,
      builder: (sheetContext) {
        final search = TextEditingController();
        final createCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = search.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? all
                : all.where((e) {
                    final id = (e['id'] ?? '').toString().toLowerCase();
                    final name = (e['name'] ?? '').toString().toLowerCase();
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
                          'Ajouter un équipement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: search,
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher équipement…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                search.clear();
                                setLocal(() {});
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bloc "création rapide" (UI un peu différente)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: createCtrl,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Créer un nouvel équipement…',
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            final name = createCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(sheetContext, _EquipPickResult.create(name));
                          },
                          child: const Text('Créer'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Aucun équipement'),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final e = filtered[i];
                              final id = (e['id'] ?? '').toString();
                              final name = (e['name'] ?? '').toString();
                              final already = assignedIds.contains(id);

                              return ListTile(
                                enabled: !already,
                                title: Text(name.isEmpty ? id : name),
                                trailing: already
                                    ? const Icon(Icons.check_circle, size: 18)
                                    : const Icon(Icons.add, size: 18),
                                onTap: already
                                    ? null
                                    : () => Navigator.pop(
                                          sheetContext,
                                          _EquipPickResult.pick(id),
                                        ),
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

    if (selected == null) return;

    try {
      final api = ApiClient();
      if (selected.mode == _EquipPickMode.pick) {
        await api.dio.post('/roles/$roleId/equipment', data: {
          'equipmentId': selected.value,
        });
      } else {
        await api.dio.post('/roles/$roleId/equipment', data: {
          'name': selected.value,
        });
      }
      await _loadRoleEquipments(roleId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur ajout équipement: $e')));
    }
  }

  Future<void> _removeEquipment(String equipmentId) async {
    final roleId = selectedRole?['id']?.toString();
    if (roleId == null || roleId.isEmpty) return;

    final eq = roleEquipments.firstWhere(
      (e) => (e['id'] ?? '').toString() == equipmentId,
      orElse: () => <String, dynamic>{},
    );
    final name = (eq['name'] ?? '').toString();

    final ok = await _confirm(
      title: 'Retirer équipement',
      message: 'Retirer "$name" de ce rôle ?',
    );
    if (!ok) return;

    try {
      final api = ApiClient();
      await api.dio.delete('/roles/$roleId/equipment/$equipmentId');
      await _loadRoleEquipments(roleId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  Future<void> _renameEquipment(String equipmentId, String currentName) async {
    final newName = await _promptText(
      title: 'Renommer équipement',
      initial: currentName,
      label: 'Nom',
      okText: 'Renommer',
    );
    if (newName == null) return;

    try {
      final api = ApiClient();
      await api.dio.patch('/equipment/$equipmentId', data: {'name': newName});
      // Reload role equipments because name changed
      final roleId = selectedRole?['id']?.toString();
      if (roleId != null && roleId.isNotEmpty) {
        await _loadRoleEquipments(roleId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur renommage: $e')));
    }
  }

  Future<void> _deleteEquipment(String equipmentId, String name) async {
    final ok = await _confirm(
      title: 'Supprimer équipement',
      message:
          'Supprimer "$name" ?\n\nAttention: impossible si déjà utilisé dans des contrôles (checks).',
    );
    if (!ok) return;

    try {
      final api = ApiClient();
      await api.dio.delete('/equipment/$equipmentId');
      final roleId = selectedRole?['id']?.toString();
      if (roleId != null && roleId.isNotEmpty) {
        await _loadRoleEquipments(roleId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Équipement supprimé')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur suppression: $e')));
    }
  }

  void _selectRole(Map<String, dynamic> role) {
    final id = role['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      selectedRole = role;
      roleEquipments = [];
    });
    _loadRoleEquipments(id);
  }

  Widget _rolesPane() {
    final list = filteredRoles;
    final selId = selectedRole?['id']?.toString();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: TextField(
            controller: searchRoleCtrl,
            decoration: InputDecoration(
              hintText: 'Rechercher rôle…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchRoleCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => searchRoleCtrl.clear(),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Aucun rôle'))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final id = (r['id'] ?? '').toString();
                    final label = (r['label'] ?? '').toString();
                    final count = r['equipmentCount'];
                    final selected = id == selId;

                    return ListTile(
                      selected: selected,
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(label.isEmpty ? id : label),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'rename') _renameRole(r);
                          if (v == 'delete') _deleteRole(r);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Renommer')),
                          PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                        ],
                      ),
                      onTap: () => _selectRole(r),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _equipmentPane({required bool isNarrow}) {
    final roleId = selectedRole?['id']?.toString();
    final roleLabel = (selectedRole?['label'] ?? '').toString();
    final list = filteredEquipments;

    if (roleId == null || roleId.isEmpty) {
      return const Center(child: Text('Sélectionne un rôle'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  roleLabel.isEmpty ? 'Équipements' : 'Équipements • $roleLabel',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Ajouter équipement',
                onPressed: _openAddEquipmentSheet,
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Rafraîchir',
                onPressed: () => _loadRoleEquipments(roleId),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            controller: searchEquipCtrl,
            decoration: InputDecoration(
              hintText: 'Filtrer équipements…',
              prefixIcon: const Icon(Icons.tune),
              suffixIcon: searchEquipCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => searchEquipCtrl.clear(),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: loadingEquip
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(child: Text('Aucun équipement pour ce rôle'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = list[i];
                        final id = (e['id'] ?? '').toString();
                        final name = (e['name'] ?? '').toString();

                        return ListTile(
                          leading: const Icon(Icons.construction_outlined),
                          title: Text(name.isEmpty ? id : name),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'remove') _removeEquipment(id);
                              if (v == 'rename') _renameEquipment(id, name);
                              if (v == 'delete') _deleteEquipment(id, name);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'remove', child: Text('Retirer du rôle')),
                              PopupMenuItem(value: 'rename', child: Text('Renommer')),
                              PopupMenuItem(value: 'delete', child: Text('Supprimer (global)')),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        if (isNarrow)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: FilledButton.icon(
              onPressed: _openAddEquipmentSheet,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un équipement'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rôles & Équipements'),
          actions: [
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: _loadRoles,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur API: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadRoles,
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
        title: const Text('Rôles & Équipements'),
        actions: [
          IconButton(
            tooltip: 'Créer rôle',
            onPressed: _createRole,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loadRoles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            // Master-detail "desktop" : deux panneaux
            return Row(
              children: [
                SizedBox(
                  width: 380,
                  child: Card(
                    margin: const EdgeInsets.all(12),
                    child: _rolesPane(),
                  ),
                ),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                    child: _equipmentPane(isNarrow: false),
                  ),
                ),
              ],
            );
          }

          // Mobile : expérience "différente" -> mini switcher Role/Equip
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Rôles'),
                      Tab(text: 'Équipements'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      Card(margin: const EdgeInsets.all(12), child: _rolesPane()),
                      Card(
                        margin: const EdgeInsets.all(12),
                        child: _equipmentPane(isNarrow: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRole,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau rôle'),
      ),
    );
  }
}

enum _EquipPickMode { pick, create }

class _EquipPickResult {
  final _EquipPickMode mode;
  final String value;

  const _EquipPickResult._(this.mode, this.value);

  static _EquipPickResult pick(String equipmentId) =>
      _EquipPickResult._(_EquipPickMode.pick, equipmentId);

  static _EquipPickResult create(String name) =>
      _EquipPickResult._(_EquipPickMode.create, name);
}