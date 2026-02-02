import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../ui/status_badge.dart';

class TeamPage extends StatefulWidget {
  final String teamId;
  const TeamPage({super.key, required this.teamId});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  bool loading = true;
  List workers = [];
  String? error;

  @override
  void initState() {
    super.initState();
    loadWorkers();
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  // ✅ Format plus lisible pour "Dernier contrôle"
  String prettyDateShort(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> loadWorkers() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get('/teams/${widget.teamId}/workers');

      setState(() {
        workers = res.data as List;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> toggleAttendance(Map w) async {
    final attendance = (w['attendance'] ?? 'PRESENT') as String;
    final isAbsent = attendance == 'ABS';
    final newStatus = isAbsent ? 'PRESENT' : 'ABS';

    try {
      final api = ApiClient();
      await api.dio.post(
        '/attendance',
        data: {'workerId': w['id'], 'status': newStatus},
      );
      await loadWorkers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur changement présence: $e')),
      );
    }
  }

  Widget _attendanceBadge({required bool isAbsent, required String status}) {
    if (isAbsent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.withOpacity(0.6)),
        ),
        child: const Text(
          'ABS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
      );
    }

    return StatusBadge(status: status);
  }

  // ✅ Petit badge "!" (alerte seuil dépassé)
  Widget _alertBang({required int alertsCount}) {
    if (alertsCount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.orange.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          const Text(
            '!',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange),
          ),
          if (alertsCount > 1) ...[
            const SizedBox(width: 6),
            Text(
              alertsCount.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.orange),
            ),
          ],
        ],
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _back(context),
          ),
          title: Text('Équipe ${widget.teamId}'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur API: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loadWorkers,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (workers.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _back(context),
          ),
          title: Text('Équipe ${widget.teamId}'),
          actions: [
            IconButton(onPressed: loadWorkers, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: const Center(child: Text("Aucun travailleur dans cette équipe.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: Text('Équipe ${widget.teamId}'),
        actions: [
          IconButton(
            onPressed: loadWorkers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: workers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final w = workers[i] as Map;

          final status = (w['status'] ?? 'OK') as String;
          final attendance = (w['attendance'] ?? 'PRESENT') as String;
          final isAbsent = attendance == 'ABS';

          // ✅ data API : hasAlert + alertsCount
          final alertsCount = (w['alertsCount'] ?? 0) is int
              ? (w['alertsCount'] ?? 0) as int
              : int.tryParse((w['alertsCount'] ?? '0').toString()) ?? 0;

          // On garde le bouton "présence" actif même si ABS,
          // mais on rend tout le reste "inactif" visuellement.
          final tileOpacity = isAbsent ? 0.45 : 1.0;

          return Opacity(
            opacity: tileOpacity,
            child: ListTile(
              dense: true,
              title: Text(
                (w['name'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAbsent ? 'Absent' : 'Présent'),

                  if ((w['controlled'] == false) && !isAbsent) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Non contrôlé',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],

                  if (w['lastCheckAt'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dernier contrôle: ${prettyDateShort(w['lastCheckAt'] as String?)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        // ✅ actif même si ABS (sinon tu ne peux plus remettre présent)
                        onPressed: () => toggleAttendance(w),
                        child: Text(isAbsent ? 'Mettre présent' : 'Mettre ABS'),
                      ),
                    ),
                  ),
                ],
              ),

              // ✅ trailing = "!" + badge
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // On affiche l'alerte même si absent ? moi je dis oui (info utile).
                  _alertBang(alertsCount: alertsCount),
                  if (alertsCount > 0) const SizedBox(width: 8),
                  _attendanceBadge(isAbsent: isAbsent, status: status),
                ],
              ),

              onTap: isAbsent
                  ? null
                  : () async {
                      final changed = await context.push('/workers/${w['id']}/check');
                      if (changed == true) loadWorkers();
                    },
            ),
          );
        },
      ),
    );
  }
}