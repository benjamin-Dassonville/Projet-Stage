import 'package:flutter/material.dart';
import '../api/api_client.dart';

class BriefingTeamDetailPage extends StatefulWidget {
  final String teamId;
  final String day; // YYYY-MM-DD
  const BriefingTeamDetailPage({super.key, required this.teamId, required this.day});

  @override
  State<BriefingTeamDetailPage> createState() => _BriefingTeamDetailPageState();
}

class _BriefingTeamDetailPageState extends State<BriefingTeamDetailPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? briefing;
  List<Map<String, dynamic>> requiredTopics = [];
  List<Map<String, dynamic>> customTopics = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _allChecked(List<Map<String, dynamic>> list) =>
      list.every((x) => x['checked'] == true);

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/briefings/team/${widget.teamId}',
          queryParameters: {'day': widget.day});

      final data = (res.data as Map).cast<String, dynamic>();
      final b = (data['briefing'] as Map).cast<String, dynamic>();

      final req = ((data['requiredTopics'] ?? []) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      final cus = ((data['customTopics'] ?? []) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();

      if (!mounted) return;
      setState(() {
        briefing = b;
        requiredTopics = req;
        customTopics = cus;
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

  @override
  Widget build(BuildContext context) {
    final done = briefing?['done'] == true;
    final valid = done && _allChecked(requiredTopics) && _allChecked(customTopics);

    return Scaffold(
      appBar: AppBar(
        title: Text('Briefing • ${widget.teamId}'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Padding(
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
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jour: ${widget.day}',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(done ? 'FAIT ✅' : 'PAS FAIT ❌',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: done ? Colors.green : Colors.red,
                                )),
                            const SizedBox(height: 6),
                            Text(valid ? 'VALIDE ✅' : 'NON VALIDE',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: valid ? Colors.green : Colors.orange,
                                )),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text('Sujets Admin (obligatoires) — ${requiredTopics.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...requiredTopics.map((t) {
                      final title = (t['title'] ?? '').toString();
                      final desc = (t['description'] ?? '').toString();
                      final checked = t['checked'] == true;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            checked ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: checked ? Colors.green : null,
                          ),
                          title: Text(title.isEmpty ? '(sans titre)' : title),
                          subtitle: desc.isEmpty ? null : Text(desc),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    Text('Sujets Chef (ajoutés) — ${customTopics.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...customTopics.map((t) {
                      final title = (t['title'] ?? '').toString();
                      final desc = (t['description'] ?? '').toString();
                      final checked = t['checked'] == true;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            checked ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: checked ? Colors.green : null,
                          ),
                          title: Text(title.isEmpty ? '(sans titre)' : title),
                          subtitle: desc.isEmpty ? null : Text(desc),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}