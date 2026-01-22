import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

class TeamControlPage extends StatefulWidget {
  const TeamControlPage({super.key});

  @override
  State<TeamControlPage> createState() => _TeamControlPageState();
}

class _TeamControlPageState extends State<TeamControlPage> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> teams = [];

  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeams();
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

  Future<void> _loadTeams() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/teams-meta?withCounts=1');
      final list = (res.data as List).cast<Map<String, dynamic>>();

      // Tri par nom (stable)
      list.sort((a, b) {
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.compareTo(bn);
      });

      setState(() {
        teams = list;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredTeams {
    final q = searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return teams;

    return teams.where((t) {
      final id = (t['id'] ?? '').toString().toLowerCase();
      final name = (t['name'] ?? '').toString().toLowerCase();
      final chefId = (t['chefId'] ?? '').toString().toLowerCase();
      return id.contains(q) || name.contains(q) || chefId.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _back,
          ),
          title: const Text('Contrôle équipes'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur API: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadTeams,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final list = filteredTeams;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: const Text('Contrôle équipes'),
        actions: [
          IconButton(
            onPressed: _loadTeams,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
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
                hintText: 'Rechercher (nom, id, chefId)…',
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
                ? const Center(child: Text('Aucune équipe'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = list[i];
                      final id = (t['id'] ?? '').toString();
                      final name = (t['name'] ?? '').toString();
                      final chefId = t['chefId']?.toString();
                      final count = t['workerCount'];

                      final subtitle = <String>[];
                      if (chefId != null && chefId.isNotEmpty) subtitle.add('chef: $chefId');
                      if (count != null) subtitle.add('workers: $count');

                      return ListTile(
                        dense: true,
                        title: Text(
                          name.isEmpty ? id : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle.join(' • ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: id.isEmpty ? null : () => context.go('/control-teams/$id'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}