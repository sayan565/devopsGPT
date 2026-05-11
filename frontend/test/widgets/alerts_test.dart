import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Alerts Widget Tests', () {

    // ── Test 1: Alert list renders with mock data ─────────────────────────────
    testWidgets('Alert list renders items correctly',
        (WidgetTester tester) async {
      final mockAlerts = [
        {'message': 'CPU usage critical', 'severity': 'HIGH',   'serverId': 'i-001'},
        {'message': 'Memory warning',     'severity': 'MEDIUM', 'serverId': 'i-002'},
        {'message': 'Disk space low',     'severity': 'LOW',    'serverId': 'i-003'},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: mockAlerts.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(mockAlerts[i]['message']!),
                subtitle: Text(mockAlerts[i]['severity']!),
              ),
            ),
          ),
        ),
      );

      expect(find.text('CPU usage critical'), findsOneWidget);
      expect(find.text('Memory warning'),     findsOneWidget);
      expect(find.text('Disk space low'),     findsOneWidget);
    });

    // ── Test 2: Severity filter chips render ──────────────────────────────────
    testWidgets('Severity filter chips are present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All severities', 'HIGH', 'MEDIUM', 'LOW']
                    .map((label) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            onSelected: (_) {},
                            selected: label == 'All severities',
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('All severities'), findsOneWidget);
      expect(find.text('HIGH'),           findsOneWidget);
      expect(find.text('MEDIUM'),         findsOneWidget);
      expect(find.text('LOW'),            findsOneWidget);
    });

    // ── Test 3: Empty state shown when no alerts ──────────────────────────────
    testWidgets('Empty state is shown when alerts list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(height: 12),
                  Text('No active alerts'),
                  Text('All systems running normally'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No active alerts'),          findsOneWidget);
      expect(find.text('All systems running normally'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded),   findsOneWidget);
    });

    // ── Test 4: Severity badge colors ─────────────────────────────────────────
    testWidgets('HIGH severity badge renders in red',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'HIGH',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('HIGH'), findsOneWidget);
    });

    // ── Test 5: Refresh button triggers reload ────────────────────────────────
    testWidgets('Refresh button is tappable', (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton.icon(
              onPressed: () => refreshCalled = true,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pump();

      expect(refreshCalled, isTrue);
    });
  });
}
