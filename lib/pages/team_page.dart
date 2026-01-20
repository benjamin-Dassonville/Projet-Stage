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
          final w = workers[i];

          final status = (w['status'] ?? 'OK') as String;
          final attendance = (w['attendance'] ?? 'PRESENT') as String;
          final isAbsent = attendance == 'ABS';

          return ListTile(
            dense: true,
            title: Text(
              w['name'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isAbsent ? Colors.grey : null,
                fontWeight: FontWeight.w600,
              ),
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
                    'Dernier contrôle: ${w['lastCheckAt']}',
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
                      onPressed: () => toggleAttendance(w as Map),
                      child: Text(isAbsent ? 'Mettre présent' : 'Mettre ABS'),
                    ),
                  ),
                ),
              ],
            ),
            trailing: StatusBadge(status: status),
            onTap: isAbsent
                ? null
                : () async {
                    final changed =
                        await context.push('/workers/${w['id']}/check');
                    if (changed == true) loadWorkers();
                  },
          );
        },
      ),
    );
  }
}