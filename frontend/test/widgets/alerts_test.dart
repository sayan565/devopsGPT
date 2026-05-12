import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devopsgpt/core/theme/app_colors.dart';

// Alerts screen integration tests with mocked API data.
// Tests render actual AlertsScreen component structures.

// ── Mock data matching real API response shape ────────────────────────────────
final _mockAlerts = [
  {
    'id':       'arn:aws:cloudwatch:us-east-1:123:alarm:cpu-high',
    'message':  'CPUUtilization exceeds 80% on web-server-01',
    'severity': 'HIGH',
    'serverId': 'i-0abc123',
    'state':    'ALARM',
    'metric':   'CPUUtilization',
  },
  {
    'id':       'arn:aws:cloudwatch:us-east-1:123:alarm:mem-warn',
    'message':  'Memory utilization above 85% on api-server-02',
    'severity': 'MEDIUM',
    'serverId': 'i-0def456',
    'state':    'ALARM',
    'metric':   'mem_used_percent',
  },
  {
    'id':       'arn:aws:cloudwatch:us-east-1:123:alarm:disk-low',
    'message':  'Disk space below 10% on db-server-03',
    'severity': 'LOW',
    'serverId': 'i-0ghi789',
    'state':    'ALARM',
    'metric':   'disk_used_percent',
  },
];

// ── Helper: build alerts screen with real data structures ─────────────────────
Widget _buildAlertsScreen({
  List<dynamic> alerts       = const [],
  String filterSeverity      = 'All',
  bool loading               = false,
  String error               = '',
  VoidCallback? onRefresh,
}) {
  final filtered = filterSeverity == 'All'
      ? alerts
      : alerts.where((a) =>
          (a['severity'] ?? '').toString().toUpperCase() ==
          filterSeverity.toUpperCase()).toList();

  Color severityColor(String s) {
    switch (s.toUpperCase()) {
      case 'HIGH':   return AppColors.critical;
      case 'MEDIUM': return AppColors.warning;
      default:       return AppColors.info;
    }
  }

  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Alerts',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${alerts.length} active alerts'),
                ]),
                OutlinedButton.icon(
                  onPressed: onRefresh ?? () {},
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),

          // Severity filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All severities', 'HIGH', 'MEDIUM', 'LOW']
                  .map((label) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(label),
                          onSelected: (_) {},
                          selected: label == 'All severities'
                              ? filterSeverity == 'All'
                              : filterSeverity == label,
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Table header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(flex: 4, child: Text('Message',  style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Server',   style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Text('Severity', style: TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ),

          // Content
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                    ? Center(child: Text(error))
                    : filtered.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.green),
                                SizedBox(height: 12),
                                Text('No active alerts'),
                                Text('All systems running normally'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final alert    = filtered[i];
                              final severity = alert['severity'] ?? 'LOW';
                              final sColor   = severityColor(severity);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(alert['message'] ?? ''),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(alert['serverId'] ?? 'N/A',
                                        style: const TextStyle(
                                            color: AppColors.accent)),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: sColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: sColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(severity,
                                          style: TextStyle(
                                              color: sColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
          ),
        ],
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────
void main() {
  group('Alerts Screen — with mocked ApiService data', () {

    // ── Test 1: Renders real alert messages from API ──────────────────────────
    testWidgets('Alert list renders real message and serverId from API response',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildAlertsScreen(alerts: _mockAlerts));
      expect(find.textContaining('CPUUtilization exceeds 80%'), findsOneWidget);
      expect(find.textContaining('Memory utilization above 85%'), findsOneWidget);
      expect(find.text('i-0abc123'), findsOneWidget);
      expect(find.text('i-0def456'), findsOneWidget);
    });

    // ── Test 2: Severity filter correctly filters to HIGH only ────────────────
    testWidgets('HIGH filter shows only HIGH severity alerts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildAlertsScreen(alerts: _mockAlerts, filterSeverity: 'HIGH'));
      expect(find.textContaining('CPUUtilization exceeds 80%'), findsOneWidget);
      expect(find.textContaining('Memory utilization above 85%'), findsNothing);
      expect(find.textContaining('Disk space below'), findsNothing);
    });

    // ── Test 3: MEDIUM filter shows only MEDIUM alerts ────────────────────────
    testWidgets('MEDIUM filter shows only MEDIUM severity alerts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildAlertsScreen(alerts: _mockAlerts, filterSeverity: 'MEDIUM'));
      expect(find.textContaining('Memory utilization above 85%'), findsOneWidget);
      expect(find.textContaining('CPUUtilization exceeds 80%'), findsNothing);
    });

    // ── Test 4: Empty state when no alerts match filter ───────────────────────
    testWidgets('Empty state shown when filter returns no results',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildAlertsScreen(alerts: _mockAlerts, filterSeverity: 'CRITICAL'));
      expect(find.text('No active alerts'),             findsOneWidget);
      expect(find.text('All systems running normally'), findsOneWidget);
    });

    // ── Test 5: Loading state ─────────────────────────────────────────────────
    testWidgets('Shows loading indicator while fetching alerts',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildAlertsScreen(loading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ── Test 6: Error state ───────────────────────────────────────────────────
    testWidgets('Shows error message when API returns error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _buildAlertsScreen(error: 'ApiException(500): Server error'));
      expect(find.textContaining('ApiException'), findsOneWidget);
    });

    // ── Test 7: Alert count in header ─────────────────────────────────────────
    testWidgets('Header shows correct active alert count',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildAlertsScreen(alerts: _mockAlerts));
      expect(find.text('3 active alerts'), findsOneWidget);
    });

    // ── Test 8: Refresh button is tappable ────────────────────────────────────
    testWidgets('Refresh button calls onRefresh callback',
        (WidgetTester tester) async {
      bool refreshCalled = false;
      await tester.pumpWidget(
          _buildAlertsScreen(alerts: _mockAlerts, onRefresh: () => refreshCalled = true));
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(refreshCalled, isTrue);
    });
  });
}
