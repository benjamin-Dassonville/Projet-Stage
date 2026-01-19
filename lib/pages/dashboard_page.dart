import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../ui/status_badge.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? kpi;
  List koWorkers = [];

  double safeRatio(num a, num b) {
    if (b == 0) return 0;
    return a / b;
  }

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final res = await api.dio.get(
        '/dashboard/summary',
        queryParameters: {'teamId': '1'}, // MVP
      );

      setState(() {
        kpi = (res.data['kpi'] as Map).cast<String, dynamic>();
        koWorkers = res.data['koWorkers'] as List;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Widget kpiCard(String title, dynamic value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${value ?? '-'}', style: const TextStyle(fontSize: 26)),
          ],
        ),
      ),
    );
  }

  int crossAxisCountForWidth(double w) {
    if (w >= 1100) return 3; // grand écran
    if (w >= 700) return 2; // tablette / web moyen
    return 1; // mobile
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur API: $error'),
        ),
      );
    }

    final data = kpi ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cols = crossAxisCountForWidth(constraints.maxWidth);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: cols == 1 ? 4.5 : 2.2,
                  children: [
                    kpiCard('Total', data['total']),
                    kpiCard('Présents', data['presents']),
                    kpiCard('Absents', data['absents']),
                    kpiCard('Conformes (OK)', data['ok']),
                    kpiCard('Non conformes (KO)', data['ko']),
                    kpiCard('Non contrôlés', data['nonControles']),
                  ],
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Taux de conformité (sur les présents)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (_) {
                            final ok = (data['ok'] ?? 0) as num;
                            final presents = (data['presents'] ?? 0) as num;
                            final ratio = safeRatio(ok, presents);
                            final pct = (ratio * 100).round();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LinearProgressIndicator(value: ratio),
                                const SizedBox(height: 8),
                                Text(
                                  '$pct% ($ok conformes / $presents présents)',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Personnes KO',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (koWorkers.isEmpty)
                  const Text('Aucune personne KO ✅')
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: koWorkers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final w = koWorkers[i];
                        return ListTile(
                          title: Text(w['name']),
                          trailing: const StatusBadge(status: 'KO'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
