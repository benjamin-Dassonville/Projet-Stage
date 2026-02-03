import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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

  // --- Mode jour ---
  bool loadingToday = true;
  String? todayError;
  String? todayDateIso; // YYYY-MM-DD
  Map<String, dynamic>? todayCheck; // null si pas de check aujourd’hui
  List todayItems = [];

  // --- Historique ---
  bool loadingHistory = true;
  String historyRange = '7d';
  List historyChecks = [];
  String? historyError;

  // --- Alertes ---
  bool loadingAlerts = true;
  List alerts = [];
  String? alertsError;

  bool loadingAuditDiff = false;
  bool hasAuditUpdate = false;

  String? auditOriginalResult;
  String? auditModifiedResult;

  // equipmentId -> {old, new}
  final Map<String, Map<String, String>> changedItemsDiff = {};

  // --- Comparaison (Original vs Modifié) ---
  final Map<String, String> originalStatusByEquipId = {};
  String? originalResult;

  String _two(int n) => n.toString().padLeft(2, '0');

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${_two(now.month)}-${_two(now.day)}';
  }

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
      return '${_two(dt.day)}/${_two(dt.month)}/${dt.year} ${_two(dt.hour)}:${_two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  @override
  void initState() {
    super.initState();
    todayDateIso = _todayIso();
    _boot();
  }

  Future<void> _boot() async {
    await loadRequiredEquipment();
    await loadTodayCheck(); // après avoir l’équipement => pré-remplissage possible
    await loadAuditDiffIfAny();
    await loadHistory();
    await loadAlerts();
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

      // init statuts par défaut
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

  /// GET /calendar/workers/:workerId?date=YYYY-MM-DD
  Future<void> loadTodayCheck() async {
    final date = todayDateIso;
    if (date == null || date.isEmpty) return;

    setState(() {
      loadingToday = true;
      todayError = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/calendar/workers/${widget.workerId}',
        queryParameters: {'date': date},
      );

      final m = (res.data as Map).cast<String, dynamic>();
      final c = (m['check'] as Map?)?.cast<String, dynamic>();
      final its = (m['items'] as List?) ?? [];

      // Reset snapshot original
      originalStatusByEquipId.clear();
      originalResult = c?['result']?.toString();

      // si check existe => pré-remplir les statuts
      if (c != null && its.isNotEmpty) {
        for (final it in its) {
          final mm = (it as Map).cast<String, dynamic>();
          final eqId = (mm['equipmentId'] ?? '').toString();
          final st = (mm['status'] ?? 'OK').toString();

          if (eqId.isNotEmpty) {
            // ✅ snapshot original
            originalStatusByEquipId[eqId] = st;

            // ✅ valeur courante affichée/éditable (pré-remplissage)
            if (statusByEquipId.containsKey(eqId)) {
              statusByEquipId[eqId] = st;
            }
          }
        }
      }

      setState(() {
        todayCheck = c;
        todayItems = its;
        loadingToday = false;
      });
    } catch (e) {
      setState(() {
        todayError = e.toString();
        loadingToday = false;
      });
    }
  }

  /// GET /workers/:workerId/checks?range=today|7d|30d|365d
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

  /// GET /workers/:workerId/alerts
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

  bool get isCompliant => !statusByEquipId.values.any((s) => s == 'MANQUANT' || s == 'KO');
  bool get hasTodayCheck => todayCheck != null;

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

  String computedResultFromSelection() {
    if (statusByEquipId.values.any((s) => s == 'KO')) return 'KO';
    if (statusByEquipId.values.any((s) => s == 'MANQUANT')) return 'NON_CONFORME';
    return 'CONFORME';
  }

  bool _isEquipChanged(String equipmentId) {
    if (!hasTodayCheck) return false; // pas d'original si pas de check
    final orig = originalStatusByEquipId[equipmentId];
    final cur = statusByEquipId[equipmentId];
    if (orig == null || cur == null) return false;
    return orig != cur;
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
                      onPressed: equipmentId.isEmpty ? null : () => resetAlertForEquipment(equipmentId),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
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

  Widget _cmpHeader({
    required String dateLabel,
    required String originalResult,
    required String modifiedResult,
  }) {
    return Row(
      children: [
        // date/heure à gauche
        Expanded(
          flex: 3,
          child: Text(
            dateLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),

        // titres colonnes au centre
        Expanded(
          flex: 4,
          child: Row(
            children: const [
              Expanded(
                child: Center(
                  child: Text('Original', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('Modifié', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),

        // résultat à droite (on affiche le modifié, et tu peux aussi afficher l’original en plus si tu veux)
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: resultChip(modifiedResult),
          ),
        ),
      ],
    );
  }

  Widget _cmpRow({
    required String label,
    required String originalStatus,
    required String modifiedStatus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      labelForStatus(originalStatus),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      labelForStatus(modifiedStatus),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(flex: 2, child: SizedBox()), // colonne “résultat” vide pour l’alignement
        ],
      ),
    );
  }

  Widget _changedRow({required String original, required String modified}) {
    final theme = Theme.of(context);
    final cOrig = theme.colorScheme.outline;
    final cMod = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Original: ${labelForStatus(original)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: cOrig),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 18),
          Expanded(
            child: Text(
              'Modifié: ${labelForStatus(modified)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800, color: cMod),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey),
        color: Colors.grey.withOpacity(0.06),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Future<void> _submitOrEdit() async {
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

      // ✅ création
      if (!hasTodayCheck) {
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

        await loadTodayCheck();
        await loadHistory();
        await loadAlerts();

        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      // ✅ modification
      final checkId = (todayCheck?['id'] ?? '').toString();
      if (checkId.isEmpty) {
        throw Exception("Check du jour invalide: id manquant.");
      }

      await api.dio.patch('/checks/$checkId', data: {'items': items});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contrôle modifié ✅')),
      );

      await loadTodayCheck();
      await loadHistory();
      await loadAlerts();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      // si POST alors que déjà existant
      if (status == 409) {
        await loadTodayCheck();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Déjà contrôlé aujourd’hui → passe en mode modification.")),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e.response?.statusCode ?? ''} ${e.response?.data ?? e.message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> loadAuditDiffIfAny() async {
    if (!hasTodayCheck) return;

    final checkId = (todayCheck?['id'] ?? '').toString();
    if (checkId.isEmpty) return;

    setState(() {
      loadingAuditDiff = true;
      hasAuditUpdate = false;
      changedItemsDiff.clear();
      auditOriginalResult = null;
      auditModifiedResult = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/check-audits/$checkId/diff');
      final m = (res.data as Map).cast<String, dynamic>();

      final hasUpdate = (m['hasUpdate'] == true);
      if (!hasUpdate) {
        setState(() {
          loadingAuditDiff = false;
          hasAuditUpdate = false;
        });
        return;
      }

      final original = (m['original'] as Map?)?.cast<String, dynamic>() ?? {};
      final modified = (m['modified'] as Map?)?.cast<String, dynamic>() ?? {};

      auditOriginalResult = (original['result'] ?? '').toString();
      auditModifiedResult = (modified['result'] ?? '').toString();

      final origItems = (original['items'] as List?) ?? [];
      final modItems = (modified['items'] as List?) ?? [];

      // map eqId -> status
      final Map<String, String> origByEq = {
        for (final it in origItems)
          ((it as Map)['equipmentId'] ?? '').toString(): ((it)['status'] ?? 'OK').toString()
      };
      final Map<String, String> modByEq = {
        for (final it in modItems)
          ((it as Map)['equipmentId'] ?? '').toString(): ((it)['status'] ?? 'OK').toString()
      };

      // diff uniquement sur ceux qui ont changé
      final allEq = <String>{...origByEq.keys, ...modByEq.keys};
      for (final eqId in allEq) {
        final o = origByEq[eqId];
        final n = modByEq[eqId];
        if (o != null && n != null && o != n) {
          changedItemsDiff[eqId] = {'old': o, 'new': n};
        }
      }

      setState(() {
        hasAuditUpdate = true;
        loadingAuditDiff = false;
      });
    } catch (_) {
      // si erreur, on n’affiche rien (pas de faux positifs)
      setState(() {
        loadingAuditDiff = false;
        hasAuditUpdate = false;
        changedItemsDiff.clear();
        auditOriginalResult = null;
        auditModifiedResult = null;
      });
    }
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
    final buttonLabel = hasTodayCheck ? 'Modifier le contrôle' : 'Valider le contrôle';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrôle travailleur'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () async {
              await loadRequiredEquipment();
              await loadTodayCheck();
              await loadAuditDiffIfAny();
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

          // Infos du jour
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Aujourd’hui (${todayDateIso ?? "-"})',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (loadingToday)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (todayError != null)
                    const Icon(Icons.error_outline, color: Colors.red)
                  else if (hasTodayCheck)
                    resultChip((todayCheck?['result'] ?? '').toString())
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: const Text(
                        'Pas de check',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
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

            final changed = _isEquipChanged(id);
            final orig = originalStatusByEquipId[id] ?? current;
            final diff = changedItemsDiff[id]; // null si pas modifié

            return Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text((e['name'] ?? '').toString()),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Statut: ${labelForStatus(current)}'),

                          // ✅ Affiché seulement si ce contrôle a été modifié ET si cet équipement a changé
                          if (hasAuditUpdate && diff != null) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                _miniTag('Original', labelForStatus(diff['old']!)),
                                _miniTag('Modifié', labelForStatus(diff['new']!)),
                              ],
                            ),
                          ],
                        ],
                      ),
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

                  // ✅ Affiché uniquement si changement
                  if (changed) ...[
                    const Divider(height: 1),
                    _changedRow(original: orig, modified: current),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: submitting ? null : _submitOrEdit,
            child: Text(submitting ? 'Envoi...' : buttonLabel),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          // Historique
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
                  initialValue: historyRange,
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
              final checkId = (c['id'] ?? '').toString();
              final isModified = (c['isModified'] == true);

              return InkWell(
                onTap: !isModified ? null : () async {
                  try {
                    final api = ApiClient();
                    final res = await api.dio.get('/check-audits/$checkId');
                    final audits = (res.data as List?) ?? [];

                    if (!mounted) return;

                    showDialog(
                      context: context, // ignore: use_build_context_synchronously
                      builder: (_) => AlertDialog(
                        title: const Text('Historique des modifications'),
                        content: SizedBox(
                          width: 520,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: audits.length,
                            itemBuilder: (_, i) {
                              final a = (audits[i] as Map).cast<String, dynamic>();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  'rev ${a['revision']} • ${a['action']} • ${a['changed_at']}\nby: ${a['changed_by']}',
                                ),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur historique: $e')),
                    );
                  }
                },
                child: Card(
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
                            if (isModified)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.orange),
                                  color: Colors.orange.withOpacity(0.10),
                                ),
                                child: const Text(
                                  'MODIF',
                                  style: TextStyle(fontWeight: FontWeight.w800),
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
                ),
              );
            }),
        ],
      ),
    );
  }
}