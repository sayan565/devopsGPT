import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../widgets/glass_card.dart';

class ServerChartsGrid extends StatelessWidget {
  final List<dynamic> servers;

  const ServerChartsGrid({
    super.key,
    required this.servers,
  });

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) return const SizedBox.shrink();

    final displayServers = servers.take(4).toList();
    final extraServers   = servers.skip(4).toList();

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: displayServers.length,
          itemBuilder: (ctx, i) =>
              _ServerMiniChart(server: displayServers[i]),
        ),

        if (extraServers.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showAllServers(context, extraServers),
            child: GlassCard(
              padding:
                  const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.more_horiz_rounded,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${extraServers.length} more servers',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAllServers(
      BuildContext context, List<dynamic> extras) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AllServersSheet(servers: extras),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _ServerMiniChart extends StatelessWidget {
  final dynamic server;
  const _ServerMiniChart({required this.server});

  @override
  Widget build(BuildContext context) {
    double cpu    = double.tryParse(server['cpu'].toString()) ?? 0;
    String name   = server['name'] ?? server['serverId'] ?? '';
    String status = server['status'] ?? 'unknown';
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

    Color color = status == 'critical'
        ? AppColors.critical
        : status == 'warning'
            ? AppColors.warning
            : AppColors.accent;

    return GestureDetector(
      onTap: () => _showChartPopup(context),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${cpu.toInt()}%',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(child: _MiniLineChart(cpu: cpu, color: color)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.touch_app_rounded,
                  color: textMuted, size: 10),
              const SizedBox(width: 3),
              Text('tap to expand',
                  style: TextStyle(color: textMuted, fontSize: 9)),
            ]),
          ],
        ),
      ),
    );
  }

  void _showChartPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ChartPopup(server: server),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _MiniLineChart extends StatelessWidget {
  final double cpu;
  final Color color;
  const _MiniLineChart({required this.cpu, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(8, (i) {
      double variation =
          (i % 3 == 0 ? -8 : i % 2 == 0 ? 5 : -3).toDouble();
      return FlSpot(i.toDouble(), (cpu + variation).clamp(0, 100));
    });
    spots.add(FlSpot(7, cpu));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _ChartPopup extends StatelessWidget {
  final dynamic server;
  const _ChartPopup({required this.server});

  @override
  Widget build(BuildContext context) {
    double cpu    = double.tryParse(server['cpu'].toString()) ?? 0;
    double memory = double.tryParse(server['memory'].toString()) ?? 0;
    String name   = server['name'] ?? server['serverId'] ?? '';
    String status = server['status'] ?? 'unknown';

    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final textPrimary   = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final textMuted     = AppTheme.textMuted(context);
    final dialogBg      = isDark
        ? const Color(0xFF0D1424).withValues(alpha: 0.97)
        : Colors.white.withValues(alpha: 0.97);

    Color statusColor = status == 'critical'
        ? AppColors.critical
        : status == 'warning'
            ? AppColors.warning
            : AppColors.success;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Header
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.inter(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                        Text(server['serverId'] ?? '',
                            style: TextStyle(
                                color: textMuted,
                                fontSize: 12)),
                      ],
                    ),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor
                              .withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close_rounded,
                            color: textMuted, size: 20),
                      ),
                    ]),
                  ],
                ),

                const SizedBox(height: 20),

                // CPU Chart
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('CPU Usage',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 13)),
                        Text('${cpu.toInt()}%',
                            style: TextStyle(
                                color: cpu > 70
                                    ? AppColors.critical
                                    : AppColors.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: _LargeLineChart(
                          cpu: cpu,
                          color: cpu > 70
                              ? AppColors.critical
                              : AppColors.accent),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Memory Chart
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Memory Usage',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 13)),
                        Text('${memory.toInt()}%',
                            style: TextStyle(
                                color: memory > 80
                                    ? AppColors.warning
                                    : AppColors.purple,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: _LargeLineChart(
                          cpu: memory,
                          color: memory > 80
                              ? AppColors.warning
                              : AppColors.purple),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Quick info chips
                Row(children: [
                  _infoChip(Icons.computer_rounded,
                      server['instanceType'] ?? 'N/A',
                      AppColors.accent),
                  const SizedBox(width: 8),
                  _infoChip(Icons.language_rounded,
                      server['publicIp'] ?? 'N/A',
                      AppColors.purple),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _LargeLineChart extends StatelessWidget {
  final double cpu;
  final Color color;
  const _LargeLineChart({required this.cpu, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textMuted = AppTheme.textMuted(context);
    final gridLine  = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);

    final spots = List.generate(12, (i) {
      double variation = [
        -10.0, 5.0, -5.0, 8.0, -3.0, 10.0,
        -7.0,  4.0, -6.0, 9.0, -4.0,  0.0
      ][i];
      return FlSpot(
          i.toDouble(), (cpu + variation).clamp(0, 100));
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: gridLine, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 25,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: TextStyle(
                    color: textMuted, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) =>
                  FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1.5,
                strokeColor: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
class _AllServersSheet extends StatelessWidget {
  final List<dynamic> servers;
  const _AllServersSheet({required this.servers});

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.textPrimary(context);
    final sheetBg     = isDark
        ? const Color(0xFF0D1424)
        : Colors.white;
    final handleColor = AppTheme.textMuted(context)
        .withValues(alpha: 0.3);
    final borderColor = isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0x20000000);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              border: Border(
                  top: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('More Servers',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: servers.length,
                    itemBuilder: (ctx, i) =>
                        _ServerMiniChart(server: servers[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
