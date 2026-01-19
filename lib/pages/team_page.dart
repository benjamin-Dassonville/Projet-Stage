import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../ui/status_badge.dart';

import '../api/api_client.dart';

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

      await loadWorkers(); // refresh liste après changement
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur changement présence: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Équipe ${widget.teamId}')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur API: $error'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Équipe ${widget.teamId}'),
        actions: [
          IconButton(
            onPressed: loadWorkers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: workers.length,
        itemBuilder: (_, i) {
          final w = workers[i];

          final status = (w['status'] ?? 'OK') as String;
          final attendance = (w['attendance'] ?? 'PRESENT') as String;
          final isAbsent = attendance == 'ABS';

          return ListTile(
            title: Text(
              w['name'],
              style: TextStyle(
                color: isAbsent ? Colors.grey : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(isAbsent ? 'Absent' : 'Présent'),
            trailing: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(status: status),
                OutlinedButton(
                  onPressed: () => toggleAttendance(w as Map),
                  child: Text(isAbsent ? 'Mettre présent' : 'Mettre ABS'),
                ),
              ],
            ),
            onTap: isAbsent
                ? null
                : () async {
                    final changed = await context.push(
                      '/workers/${w['id']}/check',
                    );
                    if (changed == true) {
                      loadWorkers();
                    }
                  },
          );
        },
      ),
    );
  }
}
