import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import 'server_detail_screen.dart';

class InfrastructureScreen extends StatefulWidget {
  const InfrastructureScreen({super.key});
  @override
  State<InfrastructureScreen> createState() =>
      _InfrastructureScreenState();
}

class _InfrastructureScreenState extends State<InfrastructureScreen> {
  List<dynamic> servers = [];
  bool loading          = true;
  String error          = '';
  Timer? _autoRefresh;
  int _countdown        = 30;
  String _filterStatus  = 'All';

  final _statusFilters = ['All', 'healthy', 'critical', 'warning', 'stopped'];

  @override
  void initState() {
    super.initState();
    loadServers();
    _autoRefresh = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) { _countdown = 30; loadServers(); }
      });
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> loadServers() async {
    try {
      final data = await ApiService.getServers();
      setState(() { servers = data; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  List<dynamic> get filteredServers => _filterStatus == 'All'
      ? servers
      : servers.where((s) => s['status'] == _filterStatus).toList();

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = AppTheme.bg(context);
    final cardColor   = AppTheme.card(context);
    final borderColor = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

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
                  Text('EC2 Instances',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('${servers.length} instances',
                      style: TextStyle(color: textMuted, fontSize: 12)),
                ]),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(children: [
                      Icon(Icons.timer_outlined,
                          color: AppColors.accent, size: 13),
                      const SizedBox(width: 4),
                      Text('${_countdown}s',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _countdown = 30);
                      loadServers();
                    },
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
                ]),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Status filter tabs ────────────────
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((f) {
                  final isSelected = _filterStatus == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filterStatus = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent.withValues(alpha: 0.6)
                              : borderColor,
                        ),
                      ),
                      child: Text(
                        f == 'All' ? 'All instances' : f.toUpperCase(),
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.accent
                              : textMuted,
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
              _tableHeader('Instance', flex: 3),
              _tableHeader('Status', flex: 2),
              _tableHeader('Type', flex: 2),
              _tableHeader('CPU / RAM', flex: 3),
            ]),
          ),

          Divider(height: 1, color: borderColor),

          // ── Table rows ────────────────────────
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent))
                : error.isNotEmpty
                    ? Center(
                        child: Text(error,
                            style: const TextStyle(
                                color: AppColors.critical)))
                    : RefreshIndicator(
                        onRefresh: loadServers,
                        color: AppColors.accent,
                        child: filteredServers.isEmpty
                            ? Center(
                                child: Text('No instances found',
                                    style: TextStyle(
                                        color: textMuted)))
                            : ListView.separated(
                                itemCount: filteredServers.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: borderColor),
                                itemBuilder: (ctx, i) =>
                                    _serverRow(filteredServers[i], ctx),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
    );
  }

  Widget _serverRow(dynamic server, BuildContext context) {
    final double cpu    = double.tryParse(server['cpu_percent']?.toString() ?? server['cpu']?.toString() ?? '0') ?? 0;
    final double memory = double.tryParse(server['memory']?.toString() ?? '0') ?? 0;
    final String status = server['state'] ?? server['status'] ?? 'unknown';
    final String name   = server['name'] ?? server['id'] ?? 'Unknown';
    final String id     = server['id'] ?? server['serverId'] ?? '';
    final String type   = server['type'] ?? server['instanceType'] ?? 'N/A';

    final textMuted   = AppTheme.textMuted(context);
    final cardColor   = AppTheme.card(context);
    final progressBg  = AppTheme.cardBorder(context);

    Color statusColor = (status == 'healthy' || status == 'running')
        ? AppColors.success
        : (status == 'critical' || status == 'terminated')
            ? AppColors.critical
            : status == 'stopped'
                ? textMuted
                : AppColors.warning;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServerDetailScreen(
              server: Map<String, dynamic>.from(server)),
        ),
      ),
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Instance name + ID
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.computer_rounded,
                        color: statusColor, size: 13),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(name,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  Text(id,
                      style: TextStyle(
                          color: textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      )),
                ]),
              ),
            ),
            // Instance type
            Expanded(
              flex: 2,
              child: Text(type,
                  style: TextStyle(
                      color: textMuted, fontSize: 11)),
            ),
            // CPU + RAM bars
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('CPU ',
                        style: TextStyle(
                            color: textMuted, fontSize: 9)),
                    Text('${cpu.toInt()}%',
                        style: TextStyle(
                          color: cpu > 70
                              ? AppColors.critical
                              : AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        )),
                  ]),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: cpu / 100,
                      backgroundColor: progressBg,
                      color: cpu > 70
                          ? AppColors.critical
                          : AppColors.accent,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('RAM ',
                        style: TextStyle(
                            color: textMuted, fontSize: 9)),
                    Text('${memory.toInt()}%',
                        style: TextStyle(
                          color: memory > 80
                              ? AppColors.warning
                              : AppColors.purple,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        )),
                  ]),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: memory / 100,
                      backgroundColor: progressBg,
                      color: memory > 80
                          ? AppColors.warning
                          : AppColors.purple,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
