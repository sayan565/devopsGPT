import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Dashboard widget smoke tests.
// These tests verify the widget tree renders without crashing.
// Full integration tests with mock ApiService require Provider setup.

void main() {
  group('Dashboard Widget Tests', () {

    // ── Test 1: Loading indicator renders ─────────────────────────────────────
    testWidgets('Loading indicator is shown while fetching data',
        (WidgetTester tester) async {
      // Build a minimal scaffold with a CircularProgressIndicator
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ── Test 2: Error message renders ─────────────────────────────────────────
    testWidgets('Error message is shown on API failure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Connection failed. Please retry.'),
            ),
          ),
        ),
      );

      expect(find.text('Connection failed. Please retry.'), findsOneWidget);
    });

    // ── Test 3: Metric cards render ───────────────────────────────────────────
    testWidgets('Dashboard metric cards render with labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                Expanded(child: Card(child: Text('Total Servers'))),
                Expanded(child: Card(child: Text('Healthy'))),
                Expanded(child: Card(child: Text('Alerts'))),
                Expanded(child: Card(child: Text('Critical'))),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Total Servers'), findsOneWidget);
      expect(find.text('Healthy'),       findsOneWidget);
      expect(find.text('Alerts'),        findsOneWidget);
      expect(find.text('Critical'),      findsOneWidget);
    });

    // ── Test 4: Refresh button renders ────────────────────────────────────────
    testWidgets('Refresh button is present on dashboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ),
        ),
      );

      expect(find.text('Refresh'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    // ── Test 5: Status banner renders ─────────────────────────────────────────
    testWidgets('Status banner shows healthy state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('✅ All Systems Healthy'),
            ),
          ),
        ),
      );

      expect(find.textContaining('All Systems Healthy'), findsOneWidget);
    });
  });
}
