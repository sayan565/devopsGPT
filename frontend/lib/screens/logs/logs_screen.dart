import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> logs  = [];
  bool loading        = true;
  String error        = '';
  String filterType   = 'ALL';

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    setState(() { loading = true; error = ''; });
    try {
      final data = await ApiService.getLogs(); // returns Map
      // ← FIXED: extract the logs list from the map
      final logsList = List<dynamic>.from(data['logs'] ?? []);
      logsList.sort((a, b) =>
          (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      setState(() {
        logs    = logsList;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error   = e.toString();
        loading = false;
      });
    }
  }

  Color getLogColor(String type) {
    switch (type) {
      case 'FIX_EXECUTED':   return AppColors.success;
      case 'AI_ANALYSIS':    return AppColors.accent;
      case 'ALERT_RECEIVED': return AppColors.warning;
      case 'FIX_ERROR':      return AppColors.critical;
      case 'HEAL_COMPLETED': return AppColors.success;
      default:               return AppColors.info;
    }
  }

  List<dynamic> get filteredLogs => filterType == 'ALL'
      ? logs
      : logs.where((l) => l['type'] == filterType).toList();

  @override
  Widget build(BuildContext context) {
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final bgColor       = AppTheme.bg(context);
    final cardColor     = AppTheme.card(context);
    final textPrimary   = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final textMuted     = AppTheme.textMuted(context);
    final unselectedBorder = isDark
        ? Colors.white24
        : const Color(0xFFCBD5E1);
    final unselectedText = isDark ? Colors.white54 : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Logs", style: TextStyle(color: textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent),
            onPressed: loadLogs,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  bool isSelected = filterType == type;
                  return GestureDetector(
                    onTap: () => setState(() => filterType = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent : bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : unselectedBorder,
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : unselectedText,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : error.isNotEmpty
                    ? Center(
                        child: Text(error,
                            style: TextStyle(color: textSecondary)))
                    : filteredLogs.isEmpty
                        ? Center(
                            child: Text("No logs found",
                                style: TextStyle(color: textMuted)))
                        : RefreshIndicator(
                            onRefresh: loadLogs,
                            color: AppColors.accent,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                String type = log['type'] ?? 'INFO';
                                final logColor = getLogColor(type);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: logColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: logColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            type,
                                            style: TextStyle(
                                              color: logColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            log['time_str'] ?? log['timestamp']?.toString() ?? '',
                                            style: TextStyle(
                                                color: textMuted, fontSize: 10),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 6),
                                      Text(
                                        log['message'] ?? '',
                                        style: TextStyle(
                                            color: textPrimary, fontSize: 12),
                                      ),
                                    ],
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