import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool loading = true;
  String? error;

  DateTime selectedDate = DateTime.now();
  List<dynamic> teams = []; // liste des équipes du jour

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  // YYYY-MM-DD
  String _dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String _prettyDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  void _backToHome() {
    // si on a une page précédente, on pop (UX classique)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // sinon on force le retour au home
      context.go('/');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;

    setState(() => selectedDate = picked);
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
        '/calendar/teams',
        queryParameters: {'date': _dateKey(selectedDate)},
      );

      setState(() {
        teams = (res.data as List?) ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
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
    final dateStr = _dateKey(selectedDate);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToHome,
        ),
        title: const Text('Calendrier des contrôles'),
        actions: [
          IconButton(
            tooltip: 'Choisir une date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date sélectionnée : ${_prettyDate(selectedDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Changer'),
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
            else if (teams.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée sur cette date.')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = teams[i] as Map;
                    final teamId = (t['teamId'] ?? '').toString();
                    final teamName = (t['teamName'] ?? teamId).toString();

                    final total = (t['totalWorkers'] ?? 0).toString();
                    final checked = (t['checkedWorkers'] ?? 0).toString();

                    final ok = (t['ok'] ?? 0).toString();
                    final non = (t['nonConforme'] ?? 0).toString();
                    final ko = (t['ko'] ?? 0).toString();
                    final none = (t['noCheck'] ?? 0).toString();

                    return ListTile(
                      title: Text(teamName),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _pill('Contrôlés: $checked/$total'),
                          _pill('OK: $ok'),
                          _pill('NC: $non'),
                          _pill('KO: $ko'),
                          _pill('Sans check: $none'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (teamId.isEmpty) return;
                        context.push('/calendar/teams/$teamId?date=$dateStr');
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