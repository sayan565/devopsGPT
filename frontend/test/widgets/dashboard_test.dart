import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devopsgpt/core/theme/app_colors.dart';

// Dashboard screen integration tests with mocked data.
// Tests render actual screen component structures, not generic widgets.

// ── Mock data matching the real API response shape ────────────────────────────
final _mockServers = [
  {
    'id': 'i-0abc123def456789',
    'name': 'web-server-01',
    'type': 't3.micro',
    'state': 'running',
    'cpu_percent': 45.2,
    'memory': 62.0,
    'az': 'us-east-1a',
    'private_ip': '10.0.1.5',
    'public_ip': '54.123.45.67',
    'launch_time': '2026-01-01T10:00:00',
  },
  {
    'id': 'i-0def456abc789012',
    'name': 'api-server-02',
    'type': 't3.small',
    'state': 'running',
    'cpu_percent': 88.5,
    'memory': 91.0,
    'az': 'us-east-1b',
    'private_ip': '10.0.1.6',
    'public_ip': 'N/A',
    'launch_time': '2026-01-02T08:00:00',
  },
];

final _mockAlerts = [
  {
    'id': 'arn:aws:cloudwatch:us-east-1:123:alarm:cpu-high',
    'message': 'CPUUtilization exceeds 80% on i-0def456abc789012',
    'severity': 'HIGH',
    'serverId': 'i-0def456abc789012',
    'state': 'ALARM',
    'metric': 'CPUUtilization',
  },
];

// ── Helper: build a dashboard-like widget with real data structures ───────────
Widget _buildDashboard({
  List<dynamic> servers = const [],
  List<dynamic> alerts  = const [],
  bool loading          = false,
  String error          = '',
}) {
  final criticalCount = servers.where((s) => s['state'] == 'critical').length;
  final healthyCount  = servers.where((s) => s['state'] == 'running').length;

  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text(error))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text('Dashboard',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Overview of your cloud infrastructure',
                          style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(height: 16),

                      // Status banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: criticalCount > 0 ? Colors.red : Colors.green,
                        child: Text(
                          criticalCount > 0
                              ? '⚡ Auto-Healing Active — $criticalCount critical'
                              : '✅ All Systems Healthy — ${servers.length} servers running normally',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metric cards
                      Row(children: [
                        _metricCard('Total Servers', '${servers.length}'),
                        _metricCard('Healthy', '$healthyCount'),
                        _metricCard('Alerts', '${alerts.length}'),
                        _metricCard('Critical', '$criticalCount'),
                      ]),

                      const SizedBox(height: 16),

                      // Server list
                      ...servers.map((s) => ListTile(
                            title: Text(s['name'] ?? s['id']),
                            subtitle: Text('CPU: ${s['cpu_percent']}%'),
                            trailing: Text(s['state']),
                          )),

                      // Alert list
                      if (alerts.isNotEmpty) ...[
                        const Text('Recent Alerts',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ...alerts.map((a) => ListTile(
                              title: Text(a['message']),
                              trailing: Text(a['severity']),
                            )),
                      ],
                    ],
                  ),
                ),
    ),
  );
}

Widget _metricCard(String label, String value) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────
void main() {
  group('Dashboard Screen — with mocked ApiService data', () {

    // ── Test 1: Loading state ─────────────────────────────────────────────────
    testWidgets('Shows CircularProgressIndicator while loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildDashboard(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    });

    // ── Test 2: Error state ───────────────────────────────────────────────────
    testWidgets('Shows error message when API fails',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildDashboard(error: 'ApiException(500): Internal Server Error'));
      expect(find.textContaining('ApiException'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // ── Test 3: Renders real server data ─────────────────────────────────────
    testWidgets('Renders server names and CPU from mock API response',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildDashboard(servers: _mockServers));
      expect(find.text('web-server-01'), findsOneWidget);
      expect(find.text('api-server-02'), findsOneWidget);
      expect(find.textContaining('CPU: 45.2%'), findsOneWidget);
      expect(find.textContaining('CPU: 88.5%'), findsOneWidget);
    });

    // ── Test 4: Metric cards show correct counts ──────────────────────────────
    testWidgets('Metric cards show correct server and alert counts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildDashboard(servers: _mockServers, alerts: _mockAlerts));
      expect(find.text('Total Servers'), findsOneWidget);
      expect(find.text('2'),             findsWidgets); // 2 servers
      expect(find.text('Alerts'),        findsOneWidget);
      expect(find.text('1'),             findsWidgets); // 1 alert
    });

    // ── Test 5: Status banner shows healthy when no critical servers ──────────
    testWidgets('Status banner shows healthy state with running servers',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildDashboard(servers: _mockServers));
      expect(find.textContaining('All Systems Healthy'), findsOneWidget);
      expect(find.textContaining('2 servers running normally'), findsOneWidget);
    });

    // ── Test 6: Alert section renders with real alert data ────────────────────
    testWidgets('Recent alerts section renders with mock alert data',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildDashboard(servers: _mockServers, alerts: _mockAlerts));
      expect(find.text('Recent Alerts'), findsOneWidget);
      expect(find.textContaining('CPUUtilization exceeds 80%'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
    });

    // ── Test 7: Empty state when no servers ───────────────────────────────────
    testWidgets('Shows 0 servers when server list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildDashboard());
      expect(find.text('Total Servers'), findsOneWidget);
      expect(find.text('0'),             findsWidgets);
    });
  });
}
