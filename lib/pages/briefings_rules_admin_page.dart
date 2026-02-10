import 'package:flutter/material.dart';

import '../api/api_client.dart';

class BriefingsRecurringRulesAdminPage extends StatefulWidget {
  const BriefingsRecurringRulesAdminPage({super.key});

  @override
  State<BriefingsRecurringRulesAdminPage> createState() =>
      _BriefingsRecurringRulesAdminPageState();
}

class _BriefingsRecurringRulesAdminPageState
    extends State<BriefingsRecurringRulesAdminPage> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> rules = [];
  List<Map<String, dynamic>> topics = [];
  List<Map<String, dynamic>> teams = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();

      final resRules = await api.dio.get('/briefings/recurring-rules');
      final resTopics = await api.dio.get('/briefings/topics');

      // teams optionnel : si tu n'as pas /teams, ça reste vide (et l'UI proposera seulement "Toutes")
      List<Map<String, dynamic>> tms = [];
      Future<void> loadTeamsFrom(String path) async {
        final resTeams = await api.dio.get(path);
        final raw = resTeams.data;
        if (raw is List) {
          tms = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
        } else {
          tms = [];
        }
        // Normalise : parfois ça peut être label au lieu de name
        for (var i = 0; i < tms.length; i++) {
          final m = tms[i];
          final name = (m['name'] ?? m['label'] ?? '').toString();
          tms[i] = {...m, 'name': name};
        }
        tms.sort((a, b) => ('${a['name'] ?? ''}')
            .toLowerCase()
            .compareTo(('${b['name'] ?? ''}').toLowerCase()));
      }
      try {
        await loadTeamsFrom('/teams-meta');
      } catch (_) {
        try {
          await loadTeamsFrom('/teams');
        } catch (_) {
          // pas de teams
        }
      }

      final listRules = (resRules.data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // tri : isoDow puis titre topic
      listRules.sort((a, b) {
        final ad = int.tryParse('${a['isoDow'] ?? 0}') ?? 0;
        final bd = int.tryParse('${b['isoDow'] ?? 0}') ?? 0;
        if (ad != bd) return ad.compareTo(bd);
        final at = ('${a['title'] ?? ''}').toLowerCase();
        final bt = ('${b['title'] ?? ''}').toLowerCase();
        return at.compareTo(bt);
      });

      final listTopics = (resTopics.data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      listTopics.sort((a, b) => ('${a['title'] ?? ''}')
          .toLowerCase()
          .compareTo(('${b['title'] ?? ''}').toLowerCase()));

      if (!mounted) return;
      setState(() {
        rules = listRules;
        topics = listTopics;
        teams = tms;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  bool _isActive(Map<String, dynamic> r) => r['isActive'] == true;

  String _teamLabel(String? teamId) {
    if (teamId == null || teamId.trim().isEmpty) return 'Toutes les équipes';
    final t = teams.firstWhere(
      (x) => ('${x['id']}') == teamId,
      orElse: () => <String, dynamic>{},
    );
    final name = (t['name'] ?? '').toString();
    return name.isEmpty ? 'Team $teamId' : name;
  }

  String _weekdayLabel(int isoDow) {
    switch (isoDow) {
      case 1:
        return 'Lundi';
      case 2:
        return 'Mardi';
      case 3:
        return 'Mercredi';
      case 4:
        return 'Jeudi';
      case 5:
        return 'Vendredi';
      case 6:
        return 'Samedi';
      case 7:
        return 'Dimanche';
      default:
        return 'Jour ?';
    }
  }

  String _periodLabel(String? startDay, String? endDay) {
    final s = (startDay ?? '').trim();
    final e = (endDay ?? '').trim();
    if (s.isEmpty && e.isEmpty) return 'Toujours';
    if (s.isNotEmpty && e.isEmpty) return 'Du $s';
    if (s.isEmpty && e.isNotEmpty) return 'Jusqu’au $e';
    return 'Du $s au $e';
  }

  Future<void> _toggleActive(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    if (id.isEmpty) return;

    final idx = rules.indexWhere((x) => ('${x['id']}') == id);
    if (idx < 0) return;

    final prev = rules[idx];
    final next = !_isActive(r);

    setState(() {
      rules[idx] = {...rules[idx], 'isActive': next, '_saving': true};
    });

    try {
      final api = ApiClient();
      final res = await api.dio.patch('/briefings/recurring-rules/$id', data: {
        'isActive': next,
      });

      final updated = (res.data as Map).cast<String, dynamic>();

      if (!mounted) return;
      setState(() {
        rules[idx] = {...updated, '_saving': false};
        // re-tri
        rules.sort((a, b) {
          final ad = int.tryParse('${a['isoDow'] ?? 0}') ?? 0;
          final bd = int.tryParse('${b['isoDow'] ?? 0}') ?? 0;
          if (ad != bd) return ad.compareTo(bd);
          final at = ('${a['title'] ?? ''}').toLowerCase();
          final bt = ('${b['title'] ?? ''}').toLowerCase();
          return at.compareTo(bt);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        rules[idx] = prev;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur activation: $e')),
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String okText = 'Confirmer',
  }) async {
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
                child: Text(okText),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _deleteRule(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    if (id.isEmpty) return;

    final isoDow = int.tryParse('${r['isoDow'] ?? 0}') ?? 0;
    final topicTitle = (r['title'] ?? '').toString();
    final teamId = (r['teamId'] ?? '').toString();
    final teamLabel = _teamLabel(teamId.isEmpty ? null : teamId);

    final ok = await _confirm(
      title: 'Supprimer règle',
      message:
          'Supprimer la règle :\n\n- ${_weekdayLabel(isoDow)}\n- ${topicTitle.isEmpty ? 'Sujet' : topicTitle}\n- $teamLabel\n\nCela n’efface aucun historique, seulement la règle.',
      okText: 'Supprimer',
    );
    if (!ok) return;

    try {
      final api = ApiClient();
      await api.dio.delete('/briefings/recurring-rules/$id');

      if (!mounted) return;
      setState(() {
        rules.removeWhere((x) => ('${x['id']}') == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Règle supprimée ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression: $e')),
      );
    }
  }

  Future<void> _pickTeamsDialog({
    required Set<String> selectedTeamIds,
  }) async {
    final searchCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final q = searchCtrl.text.trim().toLowerCase();

          final filtered = teams.where((t) {
            final id = (t['id'] ?? '').toString().toLowerCase();
            final name = (t['name'] ?? '').toString().toLowerCase();
            if (q.isEmpty) return true;
            return id.contains(q) || name.contains(q);
          }).toList();

          return AlertDialog(
            title: Text('Choisir des équipes (${selectedTeamIds.length})'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setLocal(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Rechercher…',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(ctx).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Aucun résultat.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              final tid = (t['id'] ?? '').toString();
                              final name = (t['name'] ?? '').toString();
                              final checked = selectedTeamIds.contains(tid);

                              return CheckboxListTile(
                                value: checked,
                                onChanged: (v) {
                                  if (tid.isEmpty) return;
                                  setLocal(() {
                                    if (v == true) {
                                      selectedTeamIds.add(tid);
                                    } else {
                                      selectedTeamIds.remove(tid);
                                    }
                                  });
                                },
                                title: Text(name.isEmpty ? tid : name),
                                subtitle: name.isEmpty ? null : Text(tid),
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => setLocal(() => selectedTeamIds.clear()),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Tout décocher'),
                      ),
                      const Spacer(),
                      Text('${selectedTeamIds.length} sélectionnée(s)'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===================== DIALOG CREATE / EDIT (BACKEND MATCH) =====================
  Future<void> _createOrEditRuleDialog({Map<String, dynamic>? initial}) async {
    final isEdit = initial != null;
    final id = (initial?['id'] ?? '').toString();

    // isoDow 1..7
    int isoDow = int.tryParse('${initial?['isoDow'] ?? 1}') ?? 1;
    if (isoDow < 1) isoDow = 1;
    if (isoDow > 7) isoDow = 7;

    // topicId obligatoire
    String? topicId = (initial?['topicId'] ?? '').toString();
    if (topicId != null && topicId.trim().isEmpty) topicId = null;

    // ✅ teams multi (vide = toutes)
    final selectedTeamIds = <String>{};
    final initialTeamId = (initial?['teamId'] ?? '').toString().trim();
    if (initialTeamId.isNotEmpty) {
      selectedTeamIds.add(initialTeamId);
    }
    // "Toutes les équipes" = true si aucune équipe sélectionnée
    bool allTeams = selectedTeamIds.isEmpty;

    final startCtrl =
        TextEditingController(text: (initial?['startDay'] ?? '').toString());
    final endCtrl =
        TextEditingController(text: (initial?['endDay'] ?? '').toString());

    bool isActive = initial?['isActive'] == true;

    bool validDateOrEmpty(String v) {
      final t = v.trim();
      if (t.isEmpty) return true;
      return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t);
    }

    final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              final startOk = validDateOrEmpty(startCtrl.text);
              final endOk = validDateOrEmpty(endCtrl.text);
              final topicOk = topicId != null && topicId!.trim().isNotEmpty;

              final canSave = startOk && endOk && topicOk;

              return AlertDialog(
                title: Text(isEdit ? 'Modifier règle' : 'Créer règle'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Jour
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Jour (hebdo) *',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<int>(
                            value: isoDow,
                            items: List.generate(7, (i) {
                              final v = i + 1;
                              return DropdownMenuItem<int>(
                                value: v,
                                child: Text(_weekdayLabel(v)),
                              );
                            }),
                            onChanged: (v) {
                              if (v == null) return;
                              setLocal(() => isoDow = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Sujet
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Sujet *',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String?>(
                            value: topicId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sélectionner…'),
                              ),
                              ...topics.map((t) {
                                final tid = (t['id'] ?? '').toString();
                                final title = (t['title'] ?? '').toString();
                                return DropdownMenuItem<String?>(
                                  value: tid,
                                  child: Text(title.isEmpty ? tid : title),
                                );
                              }).toList(),
                            ],
                            onChanged: (topics.isEmpty)
                                ? null
                                : (v) => setLocal(() => topicId = v),
                          ),
                        ],
                      ),
                      if (!topicOk)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Choisis un sujet.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),

                      const Divider(height: 20),

                      // ✅ Équipes (multi) : aucune sélection = "Toutes"
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Toutes les équipes'),
                        subtitle: Text(
                          teams.isNotEmpty
                              ? 'Désactive pour cibler une ou plusieurs équipes.'
                              : 'Aucune équipe disponible',
                        ),
                        value: allTeams,
                        onChanged: teams.isNotEmpty
                            ? (v) async {
                                setLocal(() {
                                  allTeams = v;
                                  if (allTeams) {
                                    selectedTeamIds.clear();
                                  }
                                });
                                // Si on passe en mode ciblé => ouvre le sélecteur
                                if (!allTeams) {
                                  await _pickTeamsDialog(selectedTeamIds: selectedTeamIds);
                                  // Si rien choisi => on revient à "Toutes"
                                  if (selectedTeamIds.isEmpty) {
                                    setLocal(() => allTeams = true);
                                  }
                                }
                              }
                            : null,
                      ),
                      if (!allTeams && teams.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Équipes sélectionnées : ${selectedTeamIds.length}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _pickTeamsDialog(selectedTeamIds: selectedTeamIds);
                                if (selectedTeamIds.isEmpty) {
                                  setLocal(() => allTeams = true);
                                } else {
                                  setLocal(() {});
                                }
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifier'),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setLocal(() => isActive = v),
                      ),

                      const Divider(height: 20),

                      // Période
                      TextField(
                        controller: startCtrl,
                        onChanged: (_) => setLocal(() {}),
                        decoration: InputDecoration(
                          labelText: 'Début (YYYY-MM-DD)',
                          helperText: 'Vide = pas de début',
                          errorText: startOk ? null : 'Format invalide',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: endCtrl,
                        onChanged: (_) => setLocal(() {}),
                        decoration: InputDecoration(
                          labelText: 'Fin (YYYY-MM-DD)',
                          helperText: 'Vide = pas de fin',
                          errorText: endOk ? null : 'Format invalide',
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
                  ElevatedButton(
                    onPressed: canSave ? () => Navigator.pop(ctx, true) : null,
                    child: Text(isEdit ? 'Enregistrer' : 'Créer'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (saved != true) return;

    final startDay = startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim();
    final endDay = endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim();
    // ✅ Targets : null => toutes, sinon une liste d'ids
    final targetTeamIds = allTeams ? <String?>[null] : selectedTeamIds.map((e) => e as String?).toList();

    try {
      final api = ApiClient();

      if (!isEdit) {
        final createdRules = <Map<String, dynamic>>[];
        final errors = <String>[];
        for (final tid in targetTeamIds) {
          try {
            final res = await api.dio.post('/briefings/recurring-rules', data: {
              'isoDow': isoDow,
              'topicId': topicId,
              'teamId': tid, // null => toutes
              'startDay': startDay,
              'endDay': endDay,
            });
            final created = (res.data as Map).cast<String, dynamic>();
            // si l'utilisateur veut inactive, on patch derrière (ton backend POST met true)
            Map<String, dynamic> finalRule = created;
            if (isActive == false) {
              final patch = await api.dio.patch(
                '/briefings/recurring-rules/${created['id']}',
                data: {'isActive': false},
              );
              finalRule = (patch.data as Map).cast<String, dynamic>();
            }
            createdRules.add(finalRule);
          } catch (e) {
            errors.add('team=${tid ?? "ALL"} → $e');
          }
        }
        if (!mounted) return;
        setState(() {
          rules = [...createdRules, ...rules];
          rules.sort((a, b) {
            final ad = int.tryParse('${a['isoDow'] ?? 0}') ?? 0;
            final bd = int.tryParse('${b['isoDow'] ?? 0}') ?? 0;
            if (ad != bd) return ad.compareTo(bd);
            final at = ('${a['title'] ?? ''}').toLowerCase();
            final bt = ('${b['title'] ?? ''}').toLowerCase();
            return at.compareTo(bt);
          });
        });
        if (errors.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Règle(s) créée(s) ✅ (${createdRules.length})')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Création partielle: ${createdRules.length} ok, ${errors.length} erreurs')),
          );
        }
        return;
      }

      // EDIT : ton backend PATCH ne supporte QUE isActive.
      // Donc ici : si tu veux éditer isoDow/topicId/teamId/startDay/endDay,
      // il faut un PATCH backend complet.
      //
      // => Solution propre côté UI (avec ton backend actuel) :
      // - supprimer la règle
      // - recréer une règle avec les nouveaux champs
      // - remettre l'activation.
      //
      // C'est le seul moyen sans toucher au backend.
      final ok = await _confirm(
        title: 'Modifier la règle',
        message:
            "Ton backend ne permet pas de modifier le jour / sujet / équipe / période (PATCH = isActive seulement).\n\n"
            "Je peux appliquer la modification en faisant :\n"
            "1) suppression de l'ancienne règle\n"
            "2) création d'une nouvelle règle\n\n"
            "Continuer ?",
        okText: 'Continuer',
      );
      if (!ok) return;

      // Delete old
      await api.dio.delete('/briefings/recurring-rules/$id');

      // Create new
      final resNew = await api.dio.post('/briefings/recurring-rules', data: {
        'isoDow': isoDow,
        'topicId': topicId,
        'teamId': targetTeamIds.first, // en mode edit, on ne prend que la première
        'startDay': startDay,
        'endDay': endDay,
      });

      Map<String, dynamic> newRule =
          (resNew.data as Map).cast<String, dynamic>();

      // Apply active state if needed
      if (isActive == false) {
        final patch = await api.dio.patch(
          '/briefings/recurring-rules/${newRule['id']}',
          data: {'isActive': false},
        );
        newRule = (patch.data as Map).cast<String, dynamic>();
      }

      if (!mounted) return;

      setState(() {
        rules.removeWhere((x) => ('${x['id']}') == id);
        rules = [newRule, ...rules];
        rules.sort((a, b) {
          final ad = int.tryParse('${a['isoDow'] ?? 0}') ?? 0;
          final bd = int.tryParse('${b['isoDow'] ?? 0}') ?? 0;
          if (ad != bd) return ad.compareTo(bd);
          final at = ('${a['title'] ?? ''}').toLowerCase();
          final bt = ('${b['title'] ?? ''}').toLowerCase();
          return at.compareTo(bt);
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Règle mise à jour ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Règles récurrentes'),
          actions: [
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Règles récurrentes'),
          actions: [
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: _loadAll,
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
                onPressed: _loadAll,
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
        title: const Text('Règles récurrentes'),
        actions: [
          IconButton(
            tooltip: 'Créer une règle',
            onPressed: () => _createOrEditRuleDialog(),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEditRuleDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: rules.isEmpty
          ? const Center(child: Text('Aucune règle'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = rules[i];

                final isoDow = int.tryParse('${r['isoDow'] ?? 0}') ?? 0;
                final teamId = (r['teamId'] ?? '').toString();
                final active = _isActive(r);
                final saving = r['_saving'] == true;

                final title = (r['title'] ?? '').toString();
                final startDay = (r['startDay'] ?? '').toString();
                final endDay = (r['endDay'] ?? '').toString();

                return Card(
                  child: ListTile(
                    title: Text(
                      '${_weekdayLabel(isoDow)} • ${title.isEmpty ? 'Sujet' : title}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_teamLabel(teamId.isEmpty ? null : teamId)} • ${_periodLabel(startDay, endDay)}',
                    ),
                    onTap: () => _createOrEditRuleDialog(initial: r),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (saving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Switch(
                            value: active,
                            onChanged: (_) => _toggleActive(r),
                          ),
                        PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (v) {
                            if (v == 'edit') _createOrEditRuleDialog(initial: r);
                            if (v == 'delete') _deleteRule(r);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined),
                                  SizedBox(width: 10),
                                  Text('Modifier'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline),
                                  SizedBox(width: 10),
                                  Text('Supprimer'),
                                ],
                              ),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.more_vert),
                          ),
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