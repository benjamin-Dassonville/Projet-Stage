import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';

class BriefingsOverviewPage extends StatefulWidget {
  const BriefingsOverviewPage({super.key});

  @override
  State<BriefingsOverviewPage> createState() => _BriefingsOverviewPageState();
}

class _BriefingsOverviewPageState extends State<BriefingsOverviewPage> {
  bool loading = true;
  String? error;

  String day = _todayIso();

  List<Map<String, dynamic>> teams = [];
  Map<String, _BriefingTeamStatus> statusByTeam = {};

  static String _todayIso() {
    final d = DateTime.now();
    final dd = DateTime(d.year, d.month, d.day);
    return dd.toIso8601String().substring(0, 10);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      statusByTeam = {};
    });

    try {
      final api = ApiClient();

      // tu utilises déjà /teams-meta dans le dashboard
      final resTeams = await api.dio.get('/teams-meta');
      final tms = (resTeams.data as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList()
        ..sort((a, b) => ('${a['name'] ?? ''}')
            .toLowerCase()
            .compareTo(('${b['name'] ?? ''}').toLowerCase()));

      // charger les briefings par équipe (simple + fiable)
      final futures = tms.map((t) async {
        final teamId = (t['id'] ?? '').toString();
        final r = await api.dio.get('/briefings/team/$teamId', queryParameters: {'day': day});
        final data = (r.data as Map).cast<String, dynamic>();

        final briefing = (data['briefing'] as Map).cast<String, dynamic>();
        final done = briefing['done'] == true;

        final required = ((data['requiredTopics'] ?? []) as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        final custom = ((data['customTopics'] ?? []) as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();

        bool allChecked(List<Map<String, dynamic>> list) =>
            list.every((x) => x['checked'] == true);

        final valid = done && allChecked(required) && allChecked(custom);

        return MapEntry(
          teamId,
          _BriefingTeamStatus(
            done: done,
            valid: valid,
            requiredCount: required.length,
            requiredChecked: required.where((x) => x['checked'] == true).length,
            customCount: custom.length,
            customChecked: custom.where((x) => x['checked'] == true).length,
          ),
        );
      }).toList();

      final entries = await Future.wait(futures);
      final map = {for (final e in entries) e.key: e.value};

      if (!mounted) return;
      setState(() {
        teams = tms;
        statusByTeam = map;
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
    final allDone = teams.isNotEmpty &&
        teams.every((t) => statusByTeam[(t['id'] ?? '').toString()]?.done == true);

    final allValid = teams.isNotEmpty &&
        teams.every((t) => statusByTeam[(t['id'] ?? '').toString()]?.valid == true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Briefings'),
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Jour: $day\n'
                                  'Tous faits: ${allDone ? "✅" : "❌"}   '
                                  'Tous valides: ${allValid ? "✅" : "❌"}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: teams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final t = teams[i];
                          final teamId = (t['id'] ?? '').toString();
                          final name = (t['name'] ?? '').toString();
                          final st = statusByTeam[teamId];

                          final done = st?.done == true;
                          final valid = st?.valid == true;

                          return Card(
                            child: ListTile(
                              title: Text(
                                name.isEmpty ? teamId : name,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: st == null
                                  ? const Text('—')
                                  : Text(
                                      'Admin: ${st.requiredChecked}/${st.requiredCount} • '
                                      'Chef: ${st.customChecked}/${st.customCount}',
                                    ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(done ? 'FAIT' : 'PAS FAIT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: done ? Colors.green : Colors.red,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(valid ? 'VALIDE ✅' : 'NON VALIDE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: valid ? Colors.green : Colors.orange,
                                      )),
                                ],
                              ),
                              onTap: () => context.push(
                                '/briefings/team/$teamId?day=$day',
                              ),
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

class _BriefingTeamStatus {
  final bool done;
  final bool valid;
  final int requiredCount;
  final int requiredChecked;
  final int customCount;
  final int customChecked;

  const _BriefingTeamStatus({
    required this.done,
    required this.valid,
    required this.requiredCount,
    required this.requiredChecked,
    required this.customCount,
    required this.customChecked,
  });
}