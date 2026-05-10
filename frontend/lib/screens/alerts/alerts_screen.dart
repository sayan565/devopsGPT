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
  List<dynamic> alerts      = [];
  bool loading              = true;
  String error              = '';
  String _filterSeverity    = 'All';

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

  Color _severityColor(String s) {
    switch (s.toUpperCase()) {
      case 'HIGH':   return AppColors.critical;
      case 'MEDIUM': return AppColors.warning;
      default:       return AppColors.info;
    }
  }

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

          // ── Page header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Alerts',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 22,
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
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Severity filter chips ────────────────────
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'HIGH', 'MEDIUM', 'LOW'].map((f) {
                  final isSelected = _filterSeverity == f;
                  final fColor = f == 'HIGH'
                      ? AppColors.critical
                      : f == 'MEDIUM'
                          ? AppColors.warning
                          : f == 'LOW'
                              ? AppColors.info
                              : AppColors.accent;
                  return GestureDetector(
                    onTap: () => setState(() => _filterSeverity = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? fColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? fColor.withValues(alpha: 0.7)
                              : borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        f == 'All' ? 'All severities' : f,
                        style: TextStyle(
                          color: isSelected ? fColor : textMuted,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
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

          // ── Table header ─────────────────────────────
          Container(
            color: isDark
                ? const Color(0xFF0A1628)
                : const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 9),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text('Message',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3))),
              Expanded(
                  flex: 2,
                  child: Text('Server',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3))),
              Expanded(
                  flex: 1,
                  child: Text('Severity',
                      style: TextStyle(
                          color: AppTheme.textSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3))),
            ]),
          ),

          Divider(height: 1, color: borderColor),

          // ── Alert rows ───────────────────────────────
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
                            const Icon(Icons.error_rounded,
                                color: AppColors.critical, size: 36),
                            const SizedBox(height: 10),
                            Text(error,
                                style: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 13),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: loadAlerts,
                              icon: const Icon(Icons.refresh_rounded,
                                  size: 14),
                              label: const Text('Retry'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: BorderSide(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
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
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.success,
                                          size: 40),
                                    ),
                                    const SizedBox(height: 14),
                                    Text('No active alerts',
                                        style: GoogleFonts.inter(
                                            color: textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('All systems running normally',
                                        style: TextStyle(
                                            color: textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredAlerts.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: borderColor),
                                itemBuilder: (context, index) {
                                  final alert = filteredAlerts[index];
                                  final severity =
                                      (alert['severity'] ?? 'LOW')
                                          .toString()
                                          .toUpperCase();
                                  final sColor = _severityColor(severity);

                                  return Container(
                                    color: cardColor,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(children: [
                                      // Message
                                      Expanded(
                                        flex: 4,
                                        child: Row(children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: sColor.withValues(
                                                  alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                                Icons.warning_amber_rounded,
                                                color: sColor,
                                                size: 13),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              alert['message'] ?? 'Alert',
                                              style: TextStyle(
                                                  color: textPrimary,
                                                  fontSize: 12,
                                                  height: 1.4),
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ]),
                                      ),
                                      // Server
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          alert['serverId'] ?? 'N/A',
                                          style: TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Severity badge
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 4),
                                          decoration: BoxDecoration(
                                            color: sColor.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: sColor.withValues(
                                                    alpha: 0.45)),
                                          ),
                                          child: Text(
                                            severity,
                                            style: TextStyle(
                                              color: sColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.3,
                                            ),
                                            textAlign: TextAlign.center,
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
