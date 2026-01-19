import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> loadRequiredEquipment() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res =
          await api.dio.get('/workers/${widget.workerId}/required-equipment');

      final newRole = res.data['role'] as String;
      final newEquipment = (res.data['equipment'] as List);

      statusByEquipId.clear();
      for (final e in newEquipment) {
        statusByEquipId[e['id']] = 'OK';
      }

      setState(() {
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

  bool get isCompliant {
    return !statusByEquipId.values.any((s) => s == 'MANQUANT' || s == 'KO');
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
        'teamId': '1',
        'result': isCompliant ? 'CONFORME' : 'NON_CONFORME',
        'items': items,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await api.dio.post('/checks', data: payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contrôle envoyé ✅')),
      );

      // Retour à la liste en indiquant "changed"
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur envoi: $e')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  Widget _statusPill() {
    final ok = isCompliant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ok ? Colors.green.withOpacity(0.35) : Colors.red.withOpacity(0.35),
        ),
      ),
      child: Text(
        ok ? 'Conforme' : 'Non conforme',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: ok ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 420;

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
          title: const Text('Contrôle travailleur'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur API: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loadRequiredEquipment,
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
        title: const Text('Contrôle travailleur'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: submitting ? null : loadRequiredEquipment,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // ✅ bouton “Valider” en bas, stable sur mobile
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: submitting ? null : submitCheck,
            child: Text(submitting ? 'Envoi...' : 'Valider le contrôle'),
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text('Worker ID: ${widget.workerId}')),
              _statusPill(),
            ],
          ),
          const SizedBox(height: 8),
          Text('Rôle mission : $role'),
          const SizedBox(height: 16),

          const Text(
            'Équipements requis :',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...equipment.map((e) {
            final id = e['id'] as String;
            final current = statusByEquipId[id] ?? 'OK';

            // ✅ labels courts en mobile pour éviter le “Manq” éclaté
            final okLabel = isNarrow ? 'OK' : 'OK';
            final missingLabel = isNarrow ? 'Manq.' : 'Manquant';
            final koLabel = 'KO';

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      e['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    // ✅ SegmentedButton full width = propre sur téléphone
                    SegmentedButton<String>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: <ButtonSegment<String>>[
                        ButtonSegment(value: 'OK', label: Text(okLabel)),
                        ButtonSegment(value: 'MANQUANT', label: Text(missingLabel)),
                        ButtonSegment(value: 'KO', label: Text(koLabel)),
                      ],
                      selected: <String>{current},
                      onSelectionChanged: (newSelection) {
                        final v = newSelection.first;
                        setState(() => statusByEquipId[id] = v);
                      },
                    ),

                    const SizedBox(height: 8),
                    Text('Statut: ${labelForStatus(current)}'),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 80), // espace pour ne pas être caché par le bouton bas
        ],
      ),
    );
  }
}