import 'package:flutter/material.dart';

import '../api/api_client.dart';

class CalendarWorkerCheckPage extends StatefulWidget {
  final String workerId;
  final String? date; // YYYY-MM-DD

  const CalendarWorkerCheckPage({
    super.key,
    required this.workerId,
    required this.date,
  });

  @override
  State<CalendarWorkerCheckPage> createState() => _CalendarWorkerCheckPageState();
}

class _CalendarWorkerCheckPageState extends State<CalendarWorkerCheckPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? worker;
  Map<String, dynamic>? check; // null si pas de check
  List<dynamic> items = [];

  // For diff
  bool loadingDiff = false;
  String? diffError;
  Map<String, dynamic>? diffData; // {hasUpdate, original, modified}
  String selectedTab = 'modified'; // 'original' or 'modified'
  List<dynamic> displayedItems = [];
  final Map<String, String> equipmentNames = {};

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

  String _labelStatus(String s) {
    switch (s) {
      case 'OK':
        return 'OK';
      case 'MANQUANT':
        return 'Manquant';
      case 'KO':
        return 'KO';
      default:
        return s;
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

  Color _colorForStatus(String s) {
    if (s == 'OK') return Colors.green;
    if (s == 'MANQUANT') return Colors.orange;
    if (s == 'KO') return Colors.red;
    return Colors.grey;
  }

  Color _colorForResult(String r) {
    if (r == 'CONFORME') return Colors.green;
    if (r == 'NON_CONFORME') return Colors.orange;
    if (r == 'KO') return Colors.red;
    return Colors.grey;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/calendar/workers/${widget.workerId}',
        queryParameters: {'date': widget.date},
      );

      final m = (res.data as Map).cast<String, dynamic>();

      setState(() {
        worker = (m['worker'] as Map?)?.cast<String, dynamic>();
        check = (m['check'] as Map?)?.cast<String, dynamic>(); // peut être null
        items = (m['items'] as List?) ?? [];
        displayedItems = items;
        equipmentNames.clear();
        for (final it in items) {
          final eid = (it['equipmentId'] ?? '').toString();
          final name = (it['equipmentName'] ?? '').toString();
          if (eid.isNotEmpty) equipmentNames[eid] = name;
        }
        loading = false;
      });

      // Load diff if modified
      final isModified = (check?['isModified'] == true);
      if (check != null && isModified) {
        _loadDiff();
      } else {
        diffData = null;
        displayedItems = items; // version normale
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _loadDiff() async {
    if (check == null) return;

    setState(() {
      loadingDiff = true;
      diffError = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/check-audits/${check!['id']}/diff');

      final d = (res.data as Map).cast<String, dynamic>();
      setState(() {
        diffData = d;
        loadingDiff = false;
        _updateDisplayedItems();
      });
    } catch (e) {
      setState(() {
        diffError = e.toString();
        loadingDiff = false;
      });
    }
  }

  void _updateDisplayedItems() {
    if (diffData == null || diffData!['hasUpdate'] != true) {
      displayedItems = items;
      return;
    }

    final snap = selectedTab == 'original' ? diffData!['original'] : diffData!['modified'];
    final rawItems = (snap['items'] as List?) ?? [];
    displayedItems = rawItems.map((it) {
      final eid = (it['equipmentId'] ?? '').toString();
      return {
        ...it,
        'equipmentName': equipmentNames[eid] ?? eid,
      };
    }).toList();
  }

  void _onTabChanged(Set<String> selection) {
    setState(() {
      selectedTab = selection.first;
      _updateDisplayedItems();
    });
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (worker?['name'] ?? widget.workerId).toString();
    final dateStr = widget.date ?? '';
    final result = (check?['result'] ?? '').toString();
    final isModified = (check?['isModified'] == true);

    return Scaffold(
      appBar: AppBar(
        title: Text('Check • $name'),
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
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text('Erreur API: $error'))
                : Column(
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
                              if (check != null && isModified)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _pill('Modifié', Colors.orange),
                                ),
                              if (check != null)
                                _pill(_labelResult(result), _colorForResult(result))
                              else
                                _pill('Aucun check', Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      if (check != null && isModified)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'original', label: Text('Original')),
                                ButtonSegment(value: 'modified', label: Text('Modifié')),
                              ],
                              selected: {selectedTab},
                              onSelectionChanged: _onTabChanged,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (check == null)
                        const Expanded(
                          child: Center(
                            child: Text("Pas de contrôle enregistré pour ce worker ce jour-là."),
                          ),
                        )
                      else if (items.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text("Contrôle trouvé, mais aucun item associé."),
                          ),
                        )
                      else
                        Expanded(
                          child: Card(
                            child: ListView.separated(
                              itemCount: displayedItems.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final it = displayedItems[i] as Map;
                                final equipName =
                                    (it['equipmentName'] ?? it['equipmentId'] ?? '-').toString();
                                final st = (it['status'] ?? '-').toString();
                                final c = _colorForStatus(st);

                                return ListTile(
                                  title: Text(equipName),
                                  trailing: _pill(_labelStatus(st), c),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}