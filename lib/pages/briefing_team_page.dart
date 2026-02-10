import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

class BriefingTeamPage extends StatefulWidget {
  final String teamId;
  final String? date;
  const BriefingTeamPage({super.key, required this.teamId, this.date});

  @override
  State<BriefingTeamPage> createState() => _BriefingTeamPageState();
}

class _BriefingTeamPageState extends State<BriefingTeamPage> {
  bool loading = true;
  bool savingDone = false;
  String? error;

  // Day sélectionné (YYYY-MM-DD)
  late String day;

  // Réponse API
  Map<String, dynamic>? briefing; // { id, teamId, day, done, doneAt, ... }
  List<Map<String, dynamic>> requiredTopics = []; // { topicId, title, description, checked, ... }
  List<Map<String, dynamic>> customTopics = []; // { id, briefingId, title, description, checked, ... }

  @override
  void initState() {
    super.initState();
    day = widget.date ?? _todayIso();
    _load();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${_two(now.month)}-${_two(now.day)}';
  }

  String _prettyDay(String iso) {
    // iso: YYYY-MM-DD
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _pickDay() async {
    final parts = day.split('-');
    DateTime initial = DateTime.now();
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        initial = DateTime(y, m, d);
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    final newDay = '${picked.year}-${_two(picked.month)}-${_two(picked.day)}';
    setState(() => day = newDay);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/briefings/team/${widget.teamId}',
        queryParameters: {'day': day},
      );

      final m = (res.data as Map).cast<String, dynamic>();
      final b = (m['briefing'] as Map?)?.cast<String, dynamic>();
      final reqList = (m['requiredTopics'] as List?) ?? [];
      final customList = (m['customTopics'] as List?) ?? [];

      setState(() {
        briefing = b;
        requiredTopics = reqList
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        customTopics = customList
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

  bool get _hasBriefingId {
    final id = (briefing?['id'] ?? '').toString();
    return id.isNotEmpty;
    // (normalement toujours vrai car l'API upsert)
  }

  String get _briefingId => (briefing?['id'] ?? '').toString();

  bool get _done => (briefing?['done'] == true);

  Future<void> _setDone(bool v) async {
    if (!_hasBriefingId) return;
    if (savingDone) return;

    // Optimistic UI
    final prev = _done;
    setState(() {
      savingDone = true;
      briefing = {...?briefing, 'done': v};
    });

    try {
      final api = ApiClient();
      final res = await api.dio.patch(
        '/briefings/$_briefingId/done',
        data: {'done': v},
      );

      final b = (res.data is Map && res.data['briefing'] is Map)
          ? (res.data['briefing'] as Map).cast<String, dynamic>()
          : null;

      if (!mounted) return;

      setState(() {
        if (b != null) briefing = b;
        savingDone = false;
      });
    } catch (e) {
      // rollback
      if (!mounted) return;
      setState(() {
        briefing = {...?briefing, 'done': prev};
        savingDone = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur mise à jour "briefing fait": $e')),
      );
    }
  }

  Future<void> _toggleTopic(String topicId, bool checked) async {
    if (!_hasBriefingId) return;
    if (topicId.isEmpty) return;

    // Optimistic UI
    final idx = requiredTopics.indexWhere((t) => '${t['topicId']}' == topicId);
    if (idx < 0) return;

    final prev = (requiredTopics[idx]['checked'] == true);

    setState(() {
      requiredTopics[idx] = {...requiredTopics[idx], 'checked': checked, '_saving': true};
    });

    try {
      final api = ApiClient();
      await api.dio.patch(
        '/briefings/$_briefingId/topics/$topicId',
        data: {'checked': checked},
      );

      if (!mounted) return;
      setState(() {
        requiredTopics[idx] = {...requiredTopics[idx], 'checked': checked, '_saving': false};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        requiredTopics[idx] = {...requiredTopics[idx], 'checked': prev, '_saving': false};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur mise à jour sujet: $e')),
      );
    }
  }

  Future<void> _openAddCustomTopicDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter un sujet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Titre *'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optionnel)'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final description = descCtrl.text.trim();

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est obligatoire.')),
      );
      return;
    }

    await _createCustomTopic(title: title, description: description.isEmpty ? null : description);
  }

  Future<void> _createCustomTopic({required String title, String? description}) async {
    try {
      final api = ApiClient();

      final briefingId = (briefing?['id'] ?? '').toString();
      if (briefingId.isEmpty) throw Exception('briefingId manquant');

      await api.dio.post(
        '/briefings/$briefingId/custom-topics',
        data: {
          'title': title,
          'description': description,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet ajouté ✅')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur ajout sujet: $e')),
      );
    }
  }

  Future<void> _toggleCustomTopic(String customId, bool checked) async {
    if (!_hasBriefingId) return;
    if (customId.isEmpty) return;

    // Optimistic UI
    final idx = customTopics.indexWhere((t) => '${t['id']}' == customId);
    if (idx < 0) return;

    final prev = (customTopics[idx]['checked'] == true);

    setState(() {
      customTopics[idx] = {...customTopics[idx], 'checked': checked, '_saving': true};
    });

    try {
      final api = ApiClient();
      await api.dio.patch(
        '/briefings/$_briefingId/custom-topics/$customId',
        data: {'checked': checked},
      );

      if (!mounted) return;
      setState(() {
        customTopics[idx] = {...customTopics[idx], 'checked': checked, '_saving': false};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        customTopics[idx] = {...customTopics[idx], 'checked': prev, '_saving': false};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sujet personnalisé: $e')),
      );
    }
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _back(context),
          ),
          title: const Text('Briefing'),
          actions: [
            IconButton(
              tooltip: 'Ajouter un sujet',
              icon: const Icon(Icons.add),
              onPressed: _openAddCustomTopicDialog,
            ),
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: _load,
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
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final done = _done;
    final totalTopics = requiredTopics.length;
    final checkedCount = requiredTopics.where((t) => t['checked'] == true).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: const Text('Briefing'),
        actions: [
          IconButton(
            tooltip: 'Choisir une date',
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: 'Ajouter un sujet',
            icon: const Icon(Icons.add),
            onPressed: _openAddCustomTopicDialog,
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Équipe: ${widget.teamId}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _pill(_prettyDay(day)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sujets cochés: $checkedCount / $totalTopics',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (savingDone)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 6),
                      Switch(
                        value: done,
                        onChanged: savingDone ? null : _setDone,
                      ),
                    ],
                  ),
                  Text(
                    done ? 'Briefing fait ✅' : 'Briefing non fait',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: done ? Colors.green : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sujets obligatoires',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickDay,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Changer date'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          if (requiredTopics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Aucun sujet obligatoire pour cette date.\n'
                'Un admin/direction peut en ajouter pour ce jour.',
              ),
            )
          else
            ...requiredTopics.map((t) {
              final topicId = (t['topicId'] ?? '').toString();
              final title = (t['title'] ?? topicId).toString();
              final desc = (t['description'] ?? '').toString();
              final checked = (t['checked'] == true);
              final saving = (t['_saving'] == true);

              return Card(
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: desc.isEmpty ? null : Text(desc),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (saving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Checkbox(
                        value: checked,
                        onChanged: saving
                            ? null
                            : (v) {
                                if (v == null) return;
                                _toggleTopic(topicId, v);
                              },
                      ),
                    ],
                  ),
                  onTap: saving
                      ? null
                      : () => _toggleTopic(topicId, !checked),
                ),
              );
            }),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Sujets ajoutés par le chef',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (customTopics.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun sujet ajouté pour ce briefing.'),
            )
          else
            ...customTopics.map((t) {
              final id = t['id'].toString();
              final title = t['title'] ?? '';
              final desc = t['description'] ?? '';
              final checked = t['checked'] == true;
              final saving = t['_saving'] == true;

              return Card(
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: desc.isEmpty ? null : Text(desc),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (saving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Checkbox(
                        value: checked,
                        onChanged: saving
                            ? null
                            : (v) {
                                if (v == null) return;
                                _toggleCustomTopic(id, v);
                              },
                      ),
                    ],
                  ),
                  onTap: saving
                      ? null
                      : () => _toggleCustomTopic(id, !checked),
                ),
              );
            }),
        ],
      ),
    );
  }
}