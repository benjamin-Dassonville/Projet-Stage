import 'package:flutter/material.dart';
import '../api/api_client.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: Text('Équipe ${widget.teamId}')),
      body: ListView.builder(
        itemCount: workers.length,
        itemBuilder: (_, i) {
          final w = workers[i];
          return ListTile(
            title: Text(w['name']),
            trailing: Text(w['status']),
            onTap: () {
              context.go('/workers/${w['id']}/check');
            },
          );
        },
      ),
    );
  }
}
