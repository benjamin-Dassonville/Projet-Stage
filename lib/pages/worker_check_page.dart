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
  List equipment = [];
  final Map<String, String> statusByEquipId = {};

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

  @override
  void initState() {
    super.initState();
    loadRequiredEquipment();
  }

  Future<void> submitCheck() async {
    setState(() => submitting = true);

    try {
      final api = ApiClient();

      final items = equipment.map((e) {
        final id = e['id'] as String;
        return {'equipmentId': id, 'status': statusByEquipId[id] ?? 'OK'};
      }).toList();

      final payload = {
        'workerId': widget.workerId,
        'teamId': '1', // MVP: en dur pour l’instant
        'result': isCompliant ? 'CONFORME' : 'NON_CONFORME',
        'items': items,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await api.dio.post('/checks', data: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contrôle envoyé ✅')));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur envoi: $e')));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> loadRequiredEquipment() async {
    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/workers/${widget.workerId}/required-equipment',
      );

      setState(() {
        role = res.data['role'];
        equipment = res.data['equipment'];
        setState(() {
          role = res.data['role'];
          equipment = res.data['equipment'];

          statusByEquipId.clear();
          for (final e in equipment) {
            statusByEquipId[e['id']] = 'OK';
          }

          loading = false;
        });
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  bool get isCompliant {
    return !statusByEquipId.values.any((s) => s == 'MANQUANT' || s == 'KO');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Contrôle travailleur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Worker ID: ${widget.workerId}'),
            const SizedBox(height: 8),
            Text('Rôle mission : $role'),
            const SizedBox(height: 8),
            Text(
              isCompliant ? 'Conforme' : 'Non conforme',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCompliant ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Équipements requis :'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: equipment.length,
                itemBuilder: (_, i) {
                  final e = equipment[i];
                  final id = e['id'] as String;
                  final current = statusByEquipId[id] ?? 'OK';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(e['name']),
                        subtitle: Text('Statut: ${labelForStatus(current)}'),
                        trailing: SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment(value: 'OK', label: Text('OK')),
                            ButtonSegment(value: 'MANQUANT', label: Text('Manquant')),
                            ButtonSegment(value: 'KO', label: Text('KO')),
                          ],
                          selected: <String>{current},
                          onSelectionChanged: (newSelection) {
                            final v = newSelection.first;
                            setState(() => statusByEquipId[id] = v);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: submitting ? null : submitCheck,
              child: Text(submitting ? 'Envoi...' : 'Valider le contrôle'),
            ),
          ],
        ),
      ),
    );
  }
}
