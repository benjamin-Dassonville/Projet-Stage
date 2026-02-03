import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

class CalendarTeamPage extends StatefulWidget {
  final String teamId;
  final String? date; // YYYY-MM-DD

  const CalendarTeamPage({
    super.key,
    required this.teamId,
    required this.date,
  });

  @override
  State<CalendarTeamPage> createState() => _CalendarTeamPageState();
}

class _CalendarTeamPageState extends State<CalendarTeamPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? team;
  List<dynamic> workers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _prettyDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/calendar/teams/${widget.teamId}',
        queryParameters: {'date': widget.date},
      );

      final m = (res.data as Map).cast<String, dynamic>();

      setState(() {
        team = (m['team'] as Map?)?.cast<String, dynamic>();
        workers = (m['workers'] as List?) ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _labelResult(String r) {
    switch (r) {
      case 'CONFORME':
        return 'Conforme';
      case 'NON_CONFORME':
        return 'Non conforme';
      case 'KO':
        return 'KO';
      default:
        return r;
    }
  }

  Color _colorResult(String r) {
    if (r == 'CONFORME') return Colors.green;
    if (r == 'NON_CONFORME') return Colors.orange;
    if (r == 'KO') return Colors.red;
    return Colors.grey;
  }

  Widget _chip(String text, {Color? c}) {
    final color = c ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamName = (team?['name'] ?? widget.teamId).toString();
    final dateStr = widget.date ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Équipe • $teamName'),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date : ${_prettyDate(dateStr)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/calendar'),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Calendrier'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Expanded(child: Center(child: Text('Erreur API: $error')))
            else if (workers.isEmpty)
              const Expanded(child: Center(child: Text('Aucun worker trouvé.')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: workers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final w = workers[i] as Map;
                    final workerId = (w['workerId'] ?? '').toString();
                    final name = (w['name'] ?? workerId).toString();
                    final hasCheck = (w['hasCheck'] ?? false) == true;

                    final result = (w['result'] ?? '').toString();

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(hasCheck ? _labelResult(result) : 'Aucun check ce jour'),
                      trailing: hasCheck
                          ? _chip(_labelResult(result), c: _colorResult(result))
                          : _chip('Sans check', c: Colors.grey),
                      onTap: () {
                        if (workerId.isEmpty) return;
                        context.push('/calendar/workers/$workerId?date=$dateStr');
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}