import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';

class WorkerCheckPage extends StatefulWidget {
  final String workerId;
  const WorkerCheckPage({super.key, required this.workerId});

  @override
  State<WorkerCheckPage> createState() => _WorkerCheckPageState();
}

class _WorkerCheckPageState extends State<WorkerCheckPage> {
  bool loading = true;
  bool submitting = false;
  String? error;

  String role = '';
  String teamId = '';
  List equipment = [];
  final Map<String, String> statusByEquipId = {};

  // --- Historique ---
  bool loadingHistory = true;
  String historyRange = '7d'; // today | 7d | 30d | 365d
  List historyChecks = [];
  String? historyError;

  // --- Alertes (seuil dépassé) ---
  bool loadingAlerts = true;
  List alerts = [];
  String? alertsError;

  String labelForStatus(String s) {
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

  String labelForResult(String r) {
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

  String prettyDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  void initState() {
    super.initState();
    loadRequiredEquipment();
    loadHistory();
    loadAlerts();
  }

  Future<void> loadRequiredEquipment() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/workers/${widget.workerId}/required-equipment');

      final newTeamId = (res.data['teamId'] ?? '').toString();
      final newRole = (res.data['role'] ?? '').toString();
      final newEquipment = (res.data['equipment'] as List?) ?? [];

      statusByEquipId.clear();
      for (final e in newEquipment) {
        final id = (e['id'] ?? '').toString();
        if (id.isNotEmpty) statusByEquipId[id] = 'OK';
      }

      setState(() {
        teamId = newTeamId;
        role = newRole;
        equipment = newEquipment;
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> loadHistory() async {
    setState(() {
      loadingHistory = true;
      historyError = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/workers/${widget.workerId}/checks',
        queryParameters: {'range': historyRange},
      );

      setState(() {
        historyChecks = (res.data['checks'] as List?) ?? [];
        loadingHistory = false;
      });
    } catch (e) {
      setState(() {
        historyError = e.toString();
        loadingHistory = false;
      });
    }
  }

  Future<void> loadAlerts() async {
    setState(() {
      loadingAlerts = true;
      alertsError = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/workers/${widget.workerId}/alerts');

      setState(() {
        alerts = (res.data['alerts'] as List?) ?? [];
        loadingAlerts = false;
      });
    } catch (e) {
      setState(() {
        alertsError = e.toString();
        loadingAlerts = false;
      });
    }
  }

  Future<void> resetAlertsAll() async {
    try {
      final api = ApiClient();
      await api.dio.post('/workers/${widget.workerId}/alerts/reset');
      await loadAlerts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alertes réinitialisées (global) ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur reset global: $e')),
      );
    }
  }

  Future<void> resetAlertForEquipment(String equipmentId) async {
    try {
      final api = ApiClient();
      await api.dio.post('/workers/${widget.workerId}/alerts/$equipmentId/reset');
      await loadAlerts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerte réinitialisée ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur reset équipement: $e')),
      );
    }
  }

  bool get isCompliant {
    return !statusByEquipId.values.any((s) => s == 'MANQUANT' || s == 'KO');
  }

  Future<void> submitCheck() async {
    setState(() => submitting = true);

    try {
      final api = ApiClient();

      if (teamId.isEmpty) {
        throw Exception('teamId manquant: vérifie /required-equipment');
      }

      final items = equipment.map((e) {
        final id = (e['id'] ?? '').toString();
        return {'equipmentId': id, 'status': statusByEquipId[id] ?? 'OK'};
      }).toList();

      final payload = {
        'workerId': widget.workerId,
        'teamId': teamId,
        'items': items,
      };

      await api.dio.post('/checks', data: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contrôle envoyé ✅')),
      );

      await loadHistory();
      await loadAlerts();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      debugPrint('POST /checks FAILED');
      debugPrint('status=${e.response?.statusCode}');
      debugPrint('data=${e.response?.data}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur envoi: ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi: $e')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Color? colorForResult(String r) {
    if (r == 'CONFORME') return Colors.green;
    if (r == 'NON_CONFORME') return Colors.orange;
    if (r == 'KO') return Colors.red;
    return null;
  }

  Widget resultChip(String result) {
    final c = colorForResult(result);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c?.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c ?? Colors.grey),
      ),
      child: Text(
        labelForResult(result),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: c ?? Colors.grey[800],
        ),
      ),
    );
  }

  Widget _alertsBanner() {
    if (loadingAlerts) return const SizedBox.shrink();

    if (alertsError != null) {
      return Card(
        elevation: 0,
        color: Colors.red.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Erreur alertes: $alertsError'),
        ),
      );
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: Colors.orange.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Attention : seuil dépassé',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ✅ Liste alertes + reset par équipement
            ...alerts.map((a) {
              final equipmentId = (a['equipmentId'] ?? '').toString();
              final name = (a['equipmentName'] ?? equipmentId).toString();
              final miss = (a['missCount'] ?? 0).toString();
              final max = (a['maxMissesBeforeNotif'] ?? 0).toString();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('• $name — $miss/$max')),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: equipmentId.isEmpty
                          ? null
                          : () => resetAlertForEquipment(equipmentId),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 6),

            // (optionnel) reset global
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: resetAlertsAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset global (tout)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contrôle travailleur')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur API: $error'),
        ),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 420;
    final missingLabel = isNarrow ? 'Manq.' : 'Manquant';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrôle travailleur'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () async {
              await loadRequiredEquipment();
              await loadHistory();
              await loadAlerts();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _alertsBanner(),
          if (!loadingAlerts && alerts.isNotEmpty) const SizedBox(height: 12),

          Text('Worker ID: ${widget.workerId}'),
          const SizedBox(height: 8),
          Text('Rôle mission : $role'),
          const SizedBox(height: 8),
          Text(
            isCompliant ? 'Conforme' : 'Non conforme / KO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCompliant ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Équipements requis :'),
          const SizedBox(height: 8),

          ...equipment.map((e) {
            final id = (e['id'] ?? '').toString();
            final current = statusByEquipId[id] ?? 'OK';

            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text((e['name'] ?? '').toString()),
                  subtitle: Text('Statut: ${labelForStatus(current)}'),
                  trailing: SizedBox(
                    width: isNarrow ? 220 : 280,
                    child: SegmentedButton<String>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: <ButtonSegment<String>>[
                        const ButtonSegment(value: 'OK', label: Text('OK')),
                        ButtonSegment(value: 'MANQUANT', label: Text(missingLabel)),
                        const ButtonSegment(value: 'KO', label: Text('KO')),
                      ],
                      selected: <String>{current},
                      onSelectionChanged: (newSelection) {
                        final v = newSelection.first;
                        setState(() => statusByEquipId[id] = v);
                      },
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: submitting ? null : submitCheck,
            child: Text(submitting ? 'Envoi...' : 'Valider le contrôle'),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Historique des contrôles',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: historyRange,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'today', child: Text("Aujourd'hui")),
                    DropdownMenuItem(value: '7d', child: Text('7 jours')),
                    DropdownMenuItem(value: '30d', child: Text('30 jours')),
                    DropdownMenuItem(value: '365d', child: Text('365 jours')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => historyRange = v);
                    loadHistory();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (loadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (historyError != null)
            Text('Erreur historique: $historyError')
          else if (historyChecks.isEmpty)
            const Text('Aucun contrôle sur la période.')
          else
            ...historyChecks.map((c) {
              final result = (c['result'] ?? '').toString();
              final createdAt = c['createdAt'] as String?;
              final items = (c['items'] as List?) ?? [];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              prettyDate(createdAt),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          resultChip(result),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        const Text(
                          'Aucun item (ou items non enregistrés).',
                          style: TextStyle(fontSize: 12),
                        )
                      else
                        ...items.map((it) {
                          final name = (it['equipmentName'] ?? it['equipmentId'] ?? '-') as String;
                          final st = (it['status'] ?? '-') as String;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(name)),
                                Text(
                                  labelForStatus(st),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}