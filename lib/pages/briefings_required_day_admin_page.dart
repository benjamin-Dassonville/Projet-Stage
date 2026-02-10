import 'package:flutter/material.dart';

import '../api/api_client.dart';

class BriefingsRequiredDayAdminPage extends StatefulWidget {
  const BriefingsRequiredDayAdminPage({super.key});

  @override
  State<BriefingsRequiredDayAdminPage> createState() =>
      _BriefingsRequiredDayAdminPageState();
}

class _BriefingsRequiredDayAdminPageState
    extends State<BriefingsRequiredDayAdminPage> {
  bool loading = true;
  bool saving = false;
  String? error;

  // Date sélectionnée (YYYY-MM-DD)
  late String day;

  // Data
  List<Map<String, dynamic>> required = []; // {id, day, topicId, title, description}
  List<Map<String, dynamic>> topics = []; // {id, title, description, isActive}

  @override
  void initState() {
    super.initState();
    day = _todayIso();
    _load();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${_two(now.month)}-${_two(now.day)}';
  }

  String _prettyDay(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    return '${p[2]}/${p[1]}/${p[0]}';
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

      // 1) Obligations pour la date
      final resReq = await api.dio.get(
        '/briefings/required',
        queryParameters: {'day': day},
      );
      final dataReq = (resReq.data as Map).cast<String, dynamic>();
      final reqList = (dataReq['required'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // 2) Catalogue sujets (pour ajouter)
      final resTopics = await api.dio.get('/briefings/topics');
      final topicsList = (resTopics.data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      // tri alpha
      topicsList.sort((a, b) =>
          (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));

      setState(() {
        required = reqList;
        topics = topicsList;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  bool _isActiveTopic(Map<String, dynamic> t) => t['isActive'] == true;

  // Topics actifs + pas déjà obligatoires
  List<Map<String, dynamic>> _availableTopicsForDay() {
    final requiredIds =
        required.map((r) => (r['topicId'] ?? '').toString()).toSet();

    final available = topics.where((t) {
      final id = (t['id'] ?? '').toString();
      return _isActiveTopic(t) && !requiredIds.contains(id);
    }).toList();

    return available;
  }

  Future<void> _openAddRequiredDialog() async {
    final available = _availableTopicsForDay();

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun sujet actif à ajouter pour cette date.")),
      );
      return;
    }

    final selectedTopicId = await showModalBottomSheet<String>(
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
                ? available
                : available.where((t) {
                    final title = (t['title'] ?? '').toString().toLowerCase();
                    final desc = (t['description'] ?? '').toString().toLowerCase();
                    return title.contains(q) || desc.contains(q);
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
                      Expanded(
                        child: Text(
                          "Ajouter une obligation (${_prettyDay(day)})",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
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
                      hintText: "Rechercher un sujet…",
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
                            child: Text("Aucun résultat"),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              final id = (t['id'] ?? '').toString();
                              final title = (t['title'] ?? '').toString();
                              final desc = (t['description'] ?? '').toString();

                              return ListTile(
                                title: Text(title),
                                subtitle: desc.isEmpty ? null : Text(desc),
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

    if (selectedTopicId == null || selectedTopicId.isEmpty) return;
    await _addRequiredTopic(selectedTopicId);
  }

  Future<void> _addRequiredTopic(String topicId) async {
    if (saving) return;

    setState(() => saving = true);

    try {
      final api = ApiClient();
      await api.dio.post('/briefings/required', data: {
        'day': day,
        'topicId': topicId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Obligation ajoutée ✅")),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur ajout obligation: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _removeRequired(String requiredId) async {
    if (requiredId.isEmpty) return;
    if (saving) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer l'obligation ?"),
        content: const Text("Ce sujet ne sera plus obligatoire à cette date."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => saving = true);

    try {
      final api = ApiClient();
      await api.dio.delete('/briefings/required/$requiredId');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Obligation supprimée ✅")),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur suppression: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text("Obligations par date")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Obligations par date"),
          actions: [
            IconButton(
              tooltip: "Rafraîchir",
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
              Text("Erreur API: $error"),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Obligations par date"),
        actions: [
          IconButton(
            tooltip: "Choisir une date",
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: "Ajouter",
            onPressed: saving ? null : _openAddRequiredDialog,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: "Rafraîchir",
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : _openAddRequiredDialog,
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Date sélectionnée",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _pill(_prettyDay(day)),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _pickDay,
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text("Changer"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(),
            ),

          if (required.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "Aucun sujet obligatoire pour cette date.\n"
                "Tu peux en ajouter avec le bouton +.",
              ),
            )
          else
            ...required.map((r) {
              final id = (r['id'] ?? '').toString();
              final title = (r['title'] ?? '').toString();
              final desc = (r['description'] ?? '').toString();

              return Card(
                child: ListTile(
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: desc.isEmpty ? null : Text(desc),
                  trailing: IconButton(
                    tooltip: "Supprimer",
                    onPressed: saving ? null : () => _removeRequired(id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}