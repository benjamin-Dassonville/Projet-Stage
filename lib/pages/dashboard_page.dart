import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

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

  bool loadingMeta = true;
  List<Map<String, dynamic>> chefs = [];
  List<Map<String, dynamic>> teams = [];

  String range = 'today';
  String? selectedChefId;
  String? selectedTeamId;

  bool kpiExpanded = true;
  bool koExpanded = true;

  double safeRatio(num a, num b) => (b == 0) ? 0 : a / b;

  @override
  void initState() {
    super.initState();
    loadMeta().then((_) => loadDashboard());
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  String teamName(String? teamId) {
    if (teamId == null) return '—';
    final t = teams.where((x) => '${x['id']}' == teamId);
    if (t.isEmpty) return teamId;
    return '${t.first['name']}';
  }

  Future<void> loadMeta() async {
    setState(() => loadingMeta = true);

    try {
      final api = ApiClient();
      final resChefs = await api.dio.get('/chefs');
      final resTeams = await api.dio.get('/teams-meta');

      setState(() {
        chefs = (resChefs.data as List).cast<Map<String, dynamic>>();
        teams = (resTeams.data as List).cast<Map<String, dynamic>>();
        loadingMeta = false;
      });
    } catch (_) {
      setState(() => loadingMeta = false);
    }
  }

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = ApiClient();
      final qp = <String, dynamic>{'range': range};
      if (selectedTeamId != null) qp['teamId'] = selectedTeamId;
      if (selectedChefId != null) qp['chefId'] = selectedChefId;

      final res = await api.dio.get('/dashboard/summary', queryParameters: qp);

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

  String rangeLabel(String r) {
    switch (r) {
      case 'today':
        return "Aujourd'hui";
      case '7d':
        return '7 jours';
      case '30d':
        return '30 jours';
      case '365d':
        return '365 jours';
      default:
        return r;
    }
  }

  Widget kpiCard(String title, dynamic value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${value ?? '-'}',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int crossAxisCountForWidth(double w) {
    if (w >= 1100) return 3;
    if (w >= 700) return 2;
    return 1;
  }

  double aspectRatioForWidth(double w) {
    if (w < 420) return 3.2;
    if (w < 700) return 2.3;
    return 2.2;
  }

  Widget _pieStatus({
    required int ok,
    required int ko,
    required int nonControles,
    required int absents,
  }) {
    final total = ok + ko + nonControles + absents;
    if (total == 0) return const Text('Aucune donnée.');

    final theme = Theme.of(context);
    final cOk = theme.colorScheme.primary;
    final cKo = theme.colorScheme.error;
    final cNc = theme.colorScheme.secondary;
    final cAbs = theme.colorScheme.outline;

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          sections: [
            PieChartSectionData(value: ok.toDouble(), title: 'OK', radius: 62, color: cOk),
            PieChartSectionData(value: ko.toDouble(), title: 'KO', radius: 62, color: cKo),
            PieChartSectionData(value: nonControles.toDouble(), title: 'NC', radius: 62, color: cNc),
            PieChartSectionData(value: absents.toDouble(), title: 'ABS', radius: 62, color: cAbs),
          ],
        ),
      ),
    );
  }

  Widget _barOkKo({required int ok, required int ko}) {
    final theme = Theme.of(context);
    final cOk = theme.colorScheme.primary;
    final cKo = theme.colorScheme.error;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (ok > ko ? ok : ko).toDouble() + 1,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final v = value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(v == 0 ? 'OK' : 'KO'),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: ok.toDouble(),
                  color: cOk,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: ko.toDouble(),
                  color: cKo,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _back(context),
            style: IconButton.styleFrom(foregroundColor: Colors.black),
          ),
          title: const Text('Dashboard'),
          actions: [
            IconButton(
              tooltip: 'Calendrier',
              onPressed: () => context.push('/calendar'),
              icon: const Icon(Icons.calendar_month),
              style: IconButton.styleFrom(foregroundColor: Colors.black),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Erreur API: $error'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final data = kpi ?? {};
    final total = (data['total'] ?? 0) as int;
    final presents = (data['presents'] ?? 0) as int;
    final absents = (data['absents'] ?? 0) as int;
    final ok = (data['ok'] ?? 0) as int;
    final ko = (data['ko'] ?? 0) as int;
    final nonControles = (data['nonControles'] ?? 0) as int;

    final ratio = safeRatio(ok, presents);
    final pct = (ratio * 100).round();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Calendrier',
            onPressed: () => context.push('/calendar'),
            icon: const Icon(Icons.calendar_month),
            style: IconButton.styleFrom(
              foregroundColor: Colors.black,
            ),
          ),
          IconButton(
            onPressed: loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            style: IconButton.styleFrom(
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cols = crossAxisCountForWidth(constraints.maxWidth);
          final ratioCards = aspectRatioForWidth(constraints.maxWidth);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Filtres', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: range,
                                decoration: const InputDecoration(
                                  labelText: 'Période',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'today', child: Text("Aujourd'hui")),
                                  DropdownMenuItem(value: '7d', child: Text('7 jours')),
                                  DropdownMenuItem(value: '30d', child: Text('30 jours')),
                                  DropdownMenuItem(value: '365d', child: Text('365 jours')),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => range = v);
                                  loadDashboard();
                                },
                              ),
                            ),
                            if (loadingMeta)
                              const Padding(
                                padding: EdgeInsets.only(top: 18),
                                child: Text('Chargement des chefs/équipes...'),
                              )
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
                                child: DropdownButtonFormField<String?>(
                                  isExpanded: true,
                                  value: selectedChefId,
                                  decoration: const InputDecoration(
                                    labelText: "Chef d'équipe (optionnel)",
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Tous', overflow: TextOverflow.ellipsis),
                                    ),
                                    ...chefs.map((c) {
                                      final id = (c['id'] ?? '').toString();
                                      final name = (c['name'] ?? '').toString();
                                      return DropdownMenuItem<String?>(
                                        value: id,
                                        child: Text(
                                          name.isEmpty ? id : name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      selectedChefId = v;
                                      if (v != null) selectedTeamId = null;
                                    });
                                    loadDashboard();
                                  },
                                ),
                              ),
                            if (!loadingMeta)
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 240, maxWidth: 340),
                                child: DropdownButtonFormField<String?>(
                                  isExpanded: true,
                                  value: selectedTeamId,
                                  decoration: const InputDecoration(
                                    labelText: 'Équipe (optionnel)',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Toutes', overflow: TextOverflow.ellipsis),
                                    ),
                                    ...teams.map((t) {
                                      final id = (t['id'] ?? '').toString();
                                      final name = (t['name'] ?? '').toString();
                                      return DropdownMenuItem<String?>(
                                        value: id,
                                        child: Text(
                                          name.isEmpty ? id : name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      selectedTeamId = v;
                                      if (v != null) selectedChefId = null;
                                    });
                                    loadDashboard();
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Vue: ${rangeLabel(range)}'
                          '${selectedChefId != null ? ' • Chef: $selectedChefId' : ''}'
                          '${selectedTeamId != null ? ' • Équipe: ${teamName(selectedTeamId)}' : ''}',
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () => context.push('/briefings/overview'),
                            icon: const Icon(Icons.checklist),
                            label: const Text('Briefing'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                ExpansionTile(
                  title: const Text('Indicateurs clés', style: TextStyle(fontWeight: FontWeight.bold)),
                  initiallyExpanded: kpiExpanded,
                  onExpansionChanged: (expanded) => setState(() => kpiExpanded = expanded),
                  children: [
                    GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: ratioCards,
                      children: [
                        kpiCard('Total', total),
                        kpiCard('Présents', presents),
                        kpiCard('Absents', absents),
                        kpiCard('Conformes (OK)', ok),
                        kpiCard('Non conformes (KO)', ko),
                        kpiCard('Non contrôlés', nonControles),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Graphiques', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Répartition statuts', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  _pieStatus(ok: ok, ko: ko, nonControles: nonControles, absents: absents),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    children: const [
                                      Text('OK'),
                                      Text('KO'),
                                      Text('NC = Non contrôlés'),
                                      Text('ABS'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('OK vs KO', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  _barOkKo(ok: ok, ko: ko),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Taux de conformité (sur les présents)',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: ratio.toDouble()),
                        const SizedBox(height: 8),
                        Text('$pct% ($ok conformes / $presents présents)'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                ExpansionTile(
                  title: const Text('Personnes KO', style: TextStyle(fontWeight: FontWeight.bold)),
                  initiallyExpanded: koExpanded,
                  onExpansionChanged: (expanded) => setState(() => koExpanded = expanded),
                  children: [
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
                            final tName = teamName('${w['teamId']}');
                            return ListTile(
                              title: Text('${w['name']}'),
                              subtitle: Text('Équipe: $tName'),
                              trailing: const StatusBadge(status: 'KO'),
                              onTap: () => context.push('/workers/${w['id']}/check'),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}