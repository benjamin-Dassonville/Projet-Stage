import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

class ControlTeamPage extends StatefulWidget {
  final String teamId;
  const ControlTeamPage({super.key, required this.teamId});

  @override
  State<ControlTeamPage> createState() => _ControlTeamPageState();
}

class _ControlTeamPageState extends State<ControlTeamPage> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> roles = [];

  final TextEditingController searchCtrl = TextEditingController();

  static const String unassignedTeamId = "UNASSIGNED";

  @override
  void initState() {
    super.initState();
    _loadAll();
    searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  String _teamLabel(Map<String, dynamic> t) {
    final name = (t['name'] ?? '').toString();
    final count = t['workerCount'];
    if (count == null) return name;
    return '$name ($count)';
  }

  String _roleLabel(String? roleId) {
    if (roleId == null || roleId.isEmpty) return '—';
    final found = roles.cast<Map<String, dynamic>>().firstWhere(
          (r) => (r['id'] ?? '').toString() == roleId,
          orElse: () => const {},
        );
    final label = (found['label'] ?? '').toString();
    return label.isNotEmpty ? label : roleId;
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();

      // teams list (pour dropdown add/edit)
      final tRes = await api.dio.get('/teams-meta?withCounts=1');
      final t = (tRes.data as List).cast<Map<String, dynamic>>();
      t.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // roles list (pour dropdown role)
      List<Map<String, dynamic>> r = [];
      try {
        final rRes = await api.dio.get('/roles');
        r = (rRes.data as List).cast<Map<String, dynamic>>();
        r.sort((a, b) => (a['label'] ?? '').toString().compareTo((b['label'] ?? '').toString()));
      } catch (_) {
        // si l'endpoint /roles n'existe pas ou pas autorisé,
        // on garde une liste vide (la page reste utilisable).
        r = [];
      }

      // workers list (team current)
      final wRes = await api.dio.get('/teams/${widget.teamId}/workers');
      final w = (wRes.data as List).cast<Map<String, dynamic>>();

      setState(() {
        teams = t;
        roles = r;
        workers = w;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredWorkers {
    final q = searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return workers;

    return workers.where((w) {
      final name = (w['name'] ?? '').toString().toLowerCase();
      final emp = (w['employeeNumber'] ?? w['employee_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || emp.contains(q);
    }).toList();
  }

  Future<bool> _confirmRemoveDialog(String workerName) async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) => AlertDialog(
            title: const Text('Confirmer le retrait'),
            content: Text(
              'Retirer "$workerName" de cette équipe ?\n\n'
              'Il sera déplacé dans "Non affectés".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _removeWorker(Map<String, dynamic> w) async {
    final workerId = (w['id'] ?? '').toString();
    final workerName = (w['name'] ?? '').toString();
    if (workerId.isEmpty) return;

    final ok = await _confirmRemoveDialog(workerName);
    if (!ok) return;

    try {
      final api = ApiClient();
      await api.dio.delete('/teams/${widget.teamId}/workers/$workerId');
      await _loadAll();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$workerName déplacé → Non affectés')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur retrait: $e')),
      );
    }
  }

  Future<void> _openAddWorkerDialog() async {
    final nameCtrl = TextEditingController();
    final empCtrl = TextEditingController();

    bool dontAssign = false;
    String selectedTeamId = widget.teamId;
    String? selectedRoleId; // null => aucun rôle

    final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) {
            return StatefulBuilder(
              builder: (ctx, setLocal) {
                return AlertDialog(
                  title: const Text('Ajouter un worker'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom (requis si création)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: empCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Matricule (employeeNumber) *',
                          ),
                        ),
                        const SizedBox(height: 10),

                        DropdownButtonFormField<String?>(
                          initialValue: selectedRoleId,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Aucun rôle'),
                            ),
                            ...roles.map((r) {
                              final id = (r['id'] ?? '').toString();
                              final label = (r['label'] ?? id).toString();
                              return DropdownMenuItem<String?>(
                                value: id,
                                child: Text(label, overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (v) => setLocal(() => selectedRoleId = v),
                          decoration: const InputDecoration(
                            labelText: 'Rôle',
                          ),
                        ),

                        const SizedBox(height: 14),
                        CheckboxListTile(
                          value: dontAssign,
                          onChanged: (v) => setLocal(() => dontAssign = v ?? false),
                          title: const Text('Ne pas assigner (Non affectés)'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        IgnorePointer(
                          ignoring: dontAssign,
                          child: Opacity(
                            opacity: dontAssign ? 0.5 : 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedTeamId,
                              items: teams
                                  .where((t) => (t['id'] ?? '').toString().isNotEmpty)
                                  .map((t) {
                                final id = t['id'].toString();
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text(_teamLabel(t), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setLocal(() => selectedTeamId = v);
                              },
                              decoration: const InputDecoration(
                                labelText: 'Équipe cible',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ajouter'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    final name = nameCtrl.text.trim();
    final employeeNumber = empCtrl.text.trim();

    nameCtrl.dispose();
    empCtrl.dispose();

    if (!saved) return;

    if (employeeNumber.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le matricule (employeeNumber) est obligatoire.')),
      );
      return;
    }

    final targetTeamId = dontAssign ? unassignedTeamId : selectedTeamId;

    try {
      final api = ApiClient();
      final payload = <String, dynamic>{'employeeNumber': employeeNumber};
      if (name.isNotEmpty) payload['name'] = name;
      if (selectedRoleId != null) payload['role'] = selectedRoleId;

      final res = await api.dio.post('/teams/$targetTeamId/workers', data: payload);

      await _loadAll();
      if (!mounted) return;

      final mode = (res.data is Map && res.data['mode'] != null)
          ? res.data['mode'].toString()
          : 'ok';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ajout: $mode')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur ajout: $e')),
      );
    }
  }

  Future<void> _openEditWorkerDialog(String workerId) async {
    try {
      final api = ApiClient();
      final wRes = await api.dio.get('/workers/$workerId');
      final w = (wRes.data as Map).cast<String, dynamic>();

      final name = (w['name'] ?? '').toString();
      final emp = (w['employeeNumber'] ?? '').toString();
      final currentTeamId = (w['teamId'] ?? '').toString();
      final currentRoleId = (w['role'] ?? '').toString();

      bool dontAssign = currentTeamId == unassignedTeamId;
      String selectedTeamId = dontAssign ? unassignedTeamId : currentTeamId;
      String? selectedRoleId = currentRoleId.isEmpty ? null : currentRoleId;

      final saved = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (_) {
              return StatefulBuilder(
                builder: (ctx, setLocal) {
                  return AlertDialog(
                    title: const Text('Modifier worker'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (emp.isNotEmpty) Text('Matricule: $emp'),
                          const SizedBox(height: 14),

                          CheckboxListTile(
                            value: dontAssign,
                            onChanged: (v) {
                              setLocal(() {
                                dontAssign = v ?? false;
                                selectedTeamId = dontAssign ? unassignedTeamId : currentTeamId;
                              });
                            },
                            title: const Text('Ne pas assigner (Non affectés)'),
                            contentPadding: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 8),
                          IgnorePointer(
                            ignoring: dontAssign,
                            child: Opacity(
                              opacity: dontAssign ? 0.5 : 1,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedTeamId,
                                items: teams
                                    .where((t) => (t['id'] ?? '').toString().isNotEmpty)
                                    .map((t) {
                                  final id = t['id'].toString();
                                  return DropdownMenuItem(
                                    value: id,
                                    child: Text((t['name'] ?? '').toString(),
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setLocal(() => selectedTeamId = v);
                                },
                                decoration: const InputDecoration(labelText: 'Équipe'),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: selectedRoleId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Aucun rôle'),
                              ),
                              ...roles.map((r) {
                                final id = (r['id'] ?? '').toString();
                                final label = (r['label'] ?? id).toString();
                                return DropdownMenuItem<String?>(
                                  value: id,
                                  child: Text(label, overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (v) => setLocal(() => selectedRoleId = v),
                            decoration: const InputDecoration(labelText: 'Rôle'),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  );
                },
              );
            },
          ) ??
          false;

      if (!saved) return;

      final newTeamId = dontAssign ? unassignedTeamId : selectedTeamId;

      await api.dio.patch(
        '/workers/$workerId/profile',
        data: {
          'teamId': newTeamId,
          // null => supprimer le rôle
          'role': selectedRoleId,
        },
      );

      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur modification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: Text('Contrôle équipe ${widget.teamId}'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur API: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final list = filteredWorkers;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Contrôle équipe ${widget.teamId}'),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            onPressed: _openAddWorkerDialog,
            icon: const Icon(Icons.person_add),
            tooltip: 'Ajouter un worker',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom ou matricule)…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => searchCtrl.clear(),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Aucun worker'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final w = list[i];
                      final id = (w['id'] ?? '').toString();
                      final name = (w['name'] ?? '').toString();
                      final attendance = (w['attendance'] ?? '').toString();
                      final status = (w['status'] ?? '').toString();
                      final roleId = (w['role'] ?? '').toString();

                      final parts = <String>[];
                      if (roleId.isNotEmpty) parts.add('Rôle: ${_roleLabel(roleId)}');
                      if (attendance.isNotEmpty) parts.add(attendance);
                      if (status.isNotEmpty) parts.add(status);

                      return ListTile(
                        dense: true,
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: parts.isEmpty ? null : Text(parts.join(' • ')),
                        onTap: id.isEmpty ? null : () => _openEditWorkerDialog(id),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove),
                          tooltip: 'Désassigner',
                          onPressed: id.isEmpty ? null : () => _removeWorker(w),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
