import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<dynamic> alerts = [];
  bool loading = true;
  String error = '';
  String _filterSeverity = 'All';

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    setState(() { loading = true; error = ''; });
    try {
      final data = await ApiService.getAlerts();
      setState(() { alerts = data; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  List<dynamic> get filteredAlerts => _filterSeverity == 'All'
      ? alerts
      : alerts.where((a) =>
          (a['severity'] ?? '').toString().toUpperCase() ==
          _filterSeverity.toUpperCase()).toList();

  @override
  Widget build(BuildContext context) {
    final bgColor     = AppTheme.bg(context);
    final cardColor   = AppTheme.card(context);
    final borderColor = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Page header ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Alerts',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('${alerts.length} active alerts',
                      style: TextStyle(color: textMuted, fontSize: 12)),
                ]),
                OutlinedButton.icon(
                  onPressed: loadAlerts,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Severity filter ───────────────────
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'HIGH', 'MEDIUM', 'LOW'].map((f) {
                  final isSelected = _filterSeverity == f;
                  Color fColor = f == 'HIGH'
                      ? AppColors.critical
                      : f == 'MEDIUM'
                          ? AppColors.warning
                          : f == 'LOW'
                              ? AppColors.info
                              : AppColors.accent;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _filterSeverity = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? fColor.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isSelected
                              ? fColor.withValues(alpha: 0.6)
                              : borderColor,
                        ),
                      ),
                      child: Text(
                        f == 'All' ? 'All severities' : f,
                        style: TextStyle(
                          color: isSelected ? fColor : textMuted,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ── Table header ──────────────────────
          Container(
            color: isDark
                ? const Color(0xFF0A1628)
                : const Color(0xFFF1F3F4),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(flex: 4,
                  child: Text('Message',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              Expanded(flex: 2,
                  child: Text('Server',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              Expanded(flex: 1,
                  child: Text('Severity',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
            ]),
          ),

          Divider(height: 1, color: borderColor),

          // ── Alert rows ────────────────────────
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent))
                : error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error,
                                color: AppColors.critical, size: 32),
                            const SizedBox(height: 8),
                            Text(error,
                                style: TextStyle(
                                    color: AppTheme.textSecondary(context))),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: loadAlerts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadAlerts,
                        color: AppColors.accent,
                        child: filteredAlerts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: AppColors.success,
                                        size: 40),
                                    const SizedBox(height: 12),
                                    Text('No active alerts',
                                        style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    Text('All systems running normally',
                                        style: TextStyle(
                                            color: textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredAlerts.length,
                                separatorBuilder: (_, _) =>
                                    Divider(height: 1, color: borderColor),
                                itemBuilder: (context, index) {
                                  final alert = filteredAlerts[index];
                                  final severity =
                                      alert['severity'] ?? 'LOW';
                                  final sColor = severity == 'HIGH'
                                      ? AppColors.critical
                                      : severity == 'MEDIUM'
                                          ? AppColors.warning
                                          : AppColors.info;
                                  return Container(
                                    color: cardColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Row(children: [
                                      Expanded(
                                        flex: 4,
                                        child: Row(children: [
                                          Icon(Icons.warning_rounded,
                                              color: sColor, size: 14),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              alert['message'] ?? 'Alert',
                                              style: TextStyle(
                                                  color: textPrimary,
                                                  fontSize: 12),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ]),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          alert['serverId'] ?? 'N/A',
                                          style: TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: sColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                                color: sColor.withValues(
                                                    alpha: 0.4)),
                                          ),
                                          child: Text(
                                            severity,
                                            style: TextStyle(
                                              color: sColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
