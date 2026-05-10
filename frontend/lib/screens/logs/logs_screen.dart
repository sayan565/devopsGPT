import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> logs = [];
  bool loading       = true;
  String error       = '';
  String filterType  = 'ALL';

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    setState(() { loading = true; error = ''; });
    try {
      final data = await ApiService.getLogs();
      final logsList = List<dynamic>.from(data['logs'] ?? []);
      logsList.sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      setState(() { logs = logsList; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Color _logColor(String type) {
    switch (type) {
      case 'FIX_EXECUTED':   return AppColors.success;
      case 'AI_ANALYSIS':    return AppColors.accent;
      case 'ALERT_RECEIVED': return AppColors.warning;
      case 'FIX_ERROR':      return AppColors.critical;
      case 'HEAL_COMPLETED': return AppColors.success;
      default:               return AppColors.info;
    }
  }

  IconData _logIcon(String type) {
    switch (type) {
      case 'FIX_EXECUTED':   return Icons.build_circle_rounded;
      case 'AI_ANALYSIS':    return Icons.smart_toy_rounded;
      case 'ALERT_RECEIVED': return Icons.notifications_rounded;
      case 'FIX_ERROR':      return Icons.error_rounded;
      case 'HEAL_COMPLETED': return Icons.healing_rounded;
      default:               return Icons.info_rounded;
    }
  }

  List<dynamic> get filteredLogs => filterType == 'ALL'
      ? logs
      : logs.where((l) => l['type'] == filterType).toList();

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
                  Text('Logs',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('${filteredLogs.length} entries',
                      style: TextStyle(color: textMuted, fontSize: 12)),
                ]),
                GestureDetector(
                  onTap: loadLogs,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: AppColors.accent, size: 18),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Filter chips ─────────────────────────────
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'ALL',
                  'ALERT_RECEIVED',
                  'AI_ANALYSIS',
                  'FIX_EXECUTED',
                  'HEAL_COMPLETED',
                  'FIX_ERROR',
                ].map((type) {
                  final isSelected = filterType == type;
                  final chipColor = type == 'ALL'
                      ? AppColors.accent
                      : _logColor(type);
                  return GestureDetector(
                    onTap: () => setState(() => filterType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? chipColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? chipColor.withValues(alpha: 0.7)
                              : borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected
                              ? chipColor
                              : isDark
                                  ? Colors.white54
                                  : AppColors.lightTextSecondary,
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

          // ── Log list ─────────────────────────────────
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
                            const Icon(Icons.cloud_off_rounded,
                                color: AppColors.critical, size: 36),
                            const SizedBox(height: 10),
                            Text(error,
                                style: TextStyle(
                                    color: AppTheme.textSecondary(context),
                                    fontSize: 13),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: loadLogs,
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
                    : filteredLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.list_alt_rounded,
                                      color: AppColors.accent,
                                      size: 36),
                                ),
                                const SizedBox(height: 14),
                                Text('No logs found',
                                    style: GoogleFonts.inter(
                                        color: textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Try a different filter',
                                    style: TextStyle(
                                        color: textMuted, fontSize: 12)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: loadLogs,
                            color: AppColors.accent,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  12, 12, 12, 12),
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                final type =
                                    (log['type'] ?? 'INFO').toString();
                                final logColor = _logColor(type);
                                final logIcon  = _logIcon(type);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          logColor.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Icon
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: logColor.withValues(
                                                alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(logIcon,
                                              color: logColor, size: 14),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: logColor
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    type,
                                                    style: TextStyle(
                                                      color: logColor,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    log['time_str'] ??
                                                        log['timestamp']
                                                            ?.toString() ??
                                                        '',
                                                    style: TextStyle(
                                                        color: textMuted,
                                                        fontSize: 10),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ]),
                                              const SizedBox(height: 6),
                                              Text(
                                                log['message'] ?? '',
                                                style: TextStyle(
                                                    color: textPrimary,
                                                    fontSize: 12,
                                                    height: 1.4),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
