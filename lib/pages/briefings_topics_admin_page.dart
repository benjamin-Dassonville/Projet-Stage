import 'package:flutter/material.dart';

import '../api/api_client.dart';

class BriefingsTopicsAdminPage extends StatefulWidget {
  const BriefingsTopicsAdminPage({super.key});

  @override
  State<BriefingsTopicsAdminPage> createState() =>
      _BriefingsTopicsAdminPageState();
}

class _BriefingsTopicsAdminPageState extends State<BriefingsTopicsAdminPage> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> topics = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------
  // Utils UI
  // ---------------------------

  bool _isActive(Map<String, dynamic> t) => t['isActive'] == true;

  void _sortTopics() {
    topics.sort((a, b) =>
        (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString()));
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // Load
  // ---------------------------

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/briefings/topics');
      final list = (res.data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      setState(() {
        topics = list;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // ---------------------------
  // Create
  // ---------------------------

  Future<void> _createTopicDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Créer un sujet'),
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
              decoration:
                  const InputDecoration(labelText: 'Description (optionnel)'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
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

    try {
      final api = ApiClient();
      final res = await api.dio.post('/briefings/topics', data: {
        'title': title,
        'description': description.isEmpty ? null : description,
      });

      final created = (res.data as Map).cast<String, dynamic>();

      if (!mounted) return;
      setState(() {
        topics = [created, ...topics];
        _sortTopics();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet créé ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur création sujet: $e')),
      );
    }
  }

  // ---------------------------
  // Edit
  // ---------------------------

  Future<void> _editTopicDialog(Map<String, dynamic> t) async {
    final topicId = (t['id'] ?? '').toString();
    if (topicId.isEmpty) return;

    final titleCtrl =
        TextEditingController(text: (t['title'] ?? '').toString());
    final descCtrl =
        TextEditingController(text: (t['description'] ?? '').toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le sujet'),
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
              decoration:
                  const InputDecoration(labelText: 'Description (optionnel)'),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final newTitle = titleCtrl.text.trim();
    final newDesc = descCtrl.text.trim();

    if (newTitle.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est obligatoire.')),
      );
      return;
    }

    try {
      final api = ApiClient();
      final res = await api.dio.patch('/briefings/topics/$topicId', data: {
        'title': newTitle,
        'description': newDesc.isEmpty ? null : newDesc,
      });

      final updated = (res.data as Map).cast<String, dynamic>();

      if (!mounted) return;
      setState(() {
        final idx =
            topics.indexWhere((x) => (x['id'] ?? '').toString() == topicId);
        if (idx >= 0) topics[idx] = updated;
        _sortTopics();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet mis à jour ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur mise à jour: $e')),
      );
    }
  }

  // ---------------------------
  // Toggle active
  // ---------------------------

  Future<void> _toggleActive(Map<String, dynamic> t) async {
    final topicId = (t['id'] ?? '').toString();
    if (topicId.isEmpty) return;

    final current = _isActive(t);
    final next = !current;

    final idx =
        topics.indexWhere((x) => (x['id'] ?? '').toString() == topicId);
    if (idx < 0) return;

    final prev = topics[idx];
    setState(() {
      topics[idx] = {...topics[idx], 'isActive': next, '_saving': true};
    });

    try {
      final api = ApiClient();
      final res = await api.dio.patch('/briefings/topics/$topicId', data: {
        'isActive': next,
      });

      final updated = (res.data as Map).cast<String, dynamic>();

      if (!mounted) return;
      setState(() {
        topics[idx] = {...updated, '_saving': false};
        _sortTopics();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        topics[idx] = prev;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur activation: $e')),
      );
    }
  }

  // ---------------------------
  // Delete strict (API DELETE) + message si refus (historique)
  // ---------------------------

  Future<void> _deleteTopicForever(Map<String, dynamic> t) async {
    final topicId = (t['id'] ?? '').toString();
    final title = (t['title'] ?? '').toString();
    if (topicId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: Text(
          '⚠️ Cette action est IRRÉVERSIBLE.\n\n'
          'Sujet : "$title"\n\n'
          'Si ce sujet est déjà utilisé (obligations / checks), '
          'il ne pourra pas être supprimé pour préserver l’historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // optimistic UI "saving"
    final idx =
        topics.indexWhere((x) => (x['id'] ?? '').toString() == topicId);
    if (idx < 0) return;
    final prev = topics[idx];

    setState(() {
      topics[idx] = {...topics[idx], '_saving': true};
    });

    try {
      final api = ApiClient();
      await api.dio.delete('/briefings/topics/$topicId');

      if (!mounted) return;
      setState(() {
        topics.removeWhere((x) => (x['id'] ?? '').toString() == topicId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet supprimé définitivement ✅')),
      );
    } catch (e) {
      // rollback saving
      if (!mounted) return;
      setState(() {
        topics[idx] = prev;
      });

      final msg = e.toString().toLowerCase();

      // Si ton API renvoie 409 quand utilisé -> on explique proprement
      if (msg.contains('409') ||
          msg.contains('conflict') ||
          msg.contains('cannot be deleted') ||
          msg.contains('used')) {
        await _showInfoDialog(
          title: 'Suppression impossible',
          message:
              'Ce sujet est déjà utilisé (briefings passés / obligations / checks).\n\n'
              'Pour préserver l’historique, il ne peut pas être supprimé définitivement.\n\n'
              'Solution : utilise “Retirer (inactif)” pour le masquer des nouveaux briefings.',
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression: $e')),
      );
    }
  }

  // ---------------------------
  // Retirer = inactif (safe)
  // ---------------------------

  Future<void> _removeTopic(Map<String, dynamic> t) async {
    final topicId = (t['id'] ?? '').toString();
    final title = (t['title'] ?? '').toString();
    if (topicId.isEmpty) return;

    if (_isActive(t) == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet déjà inactif.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer le sujet ?'),
        content: Text(
          '“$title” ne sera plus disponible dans les briefings.\n\n'
          'Il ne sera pas supprimé de la base (historique conservé), '
          'il sera juste marqué INACTIF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final idx =
        topics.indexWhere((x) => (x['id'] ?? '').toString() == topicId);
    if (idx < 0) return;

    final prev = topics[idx];
    setState(() {
      topics[idx] = {...topics[idx], '_saving': true};
    });

    try {
      final api = ApiClient();
      final res = await api.dio.patch('/briefings/topics/$topicId', data: {
        'isActive': false,
      });

      final updated = (res.data as Map).cast<String, dynamic>();

      if (!mounted) return;
      setState(() {
        topics[idx] = {...updated, '_saving': false};
        _sortTopics();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sujet retiré (inactif) ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        topics[idx] = prev;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur retrait: $e')),
      );
    }
  }

  // ---------------------------
  // UI
  // ---------------------------

  Widget _statusPill(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.15),
        border: Border.all(
          color: active
              ? Colors.green.withOpacity(0.6)
              : Colors.grey.withOpacity(0.6),
        ),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: active ? Colors.green : Colors.grey[700],
        ),
      ),
    );
  }

  PopupMenuButton<String> _moreMenu(Map<String, dynamic> t) {
    final active = _isActive(t);
    final saving = t['_saving'] == true;

    return PopupMenuButton<String>(
      tooltip: 'Actions',
      enabled: !saving,
      onSelected: (v) {
        if (v == 'edit') _editTopicDialog(t);
        if (v == 'remove') _removeTopic(t);
        if (v == 'delete_forever') _deleteTopicForever(t);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
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
          value: 'remove',
          enabled: active,
          child: const Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 10),
              Text('Retirer (inactif)'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete_forever',
          child: Row(
            children: [
              Icon(Icons.delete_forever),
              SizedBox(width: 10),
              Text('Supprimer définitivement'),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.more_vert),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sujets de briefing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sujets de briefing'),
          actions: [
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sujets de briefing'),
        actions: [
          IconButton(
            tooltip: 'Créer un sujet',
            onPressed: _createTopicDialog,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTopicDialog,
        icon: const Icon(Icons.add),
        label: const Text('Créer'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = topics[i];
          final title = (t['title'] ?? '').toString();
          final desc = (t['description'] ?? '').toString();
          final active = _isActive(t);
          final saving = t['_saving'] == true;

          return Card(
            child: ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: desc.isEmpty ? null : Text(desc),
              onTap: () => _editTopicDialog(t),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statusPill(active),
                  const SizedBox(width: 10),
                  if (saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: active,
                      onChanged: (_) => _toggleActive(t),
                    ),
                  _moreMenu(t),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}