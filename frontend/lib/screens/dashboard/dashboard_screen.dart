import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_logo.dart';
import '../../services/api_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/server_chart_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _wsService = WebSocketService(); // ← FIXED: added this

  List<dynamic> servers = [];
  List<dynamic> alerts  = [];
  bool loading          = true;
  String error          = '';
  Timer? _autoRefresh;
  int _countdown        = 30;
  StreamSubscription? _wsSub;
  bool _wsConnected     = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOut);
    loadData();
    _startAutoRefresh();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    _wsService.connect(); // ← FIXED
    _wsSub = _wsService.stream.listen((data) { // ← FIXED
      if (!mounted) return;
      if (data['type'] == 'metrics_update') {
        setState(() {
          if (data['servers'] != null) servers = data['servers'];
          if (data['alerts']  != null) alerts  = data['alerts'];
          _wsConnected = true;
          _countdown = 30;
        });
        _fadeController.forward(from: 0);
      }
    });
  }

  void _startAutoRefresh() {
    _autoRefresh = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) { _countdown = 30; loadData(); }
      });
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _wsSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (!loading) setState(() { loading = true; error = ''; });
    try {
      final results = await Future.wait([
        ApiService.getServers(),
        ApiService.getAlerts(),
      ]);
      setState(() {
        servers = results[0];
        alerts  = results[1];
        loading = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  int get healthyCount  => servers.where((s) => s['status'] == 'healthy').length;
  int get criticalCount => servers.where((s) => s['status'] == 'critical').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.bg(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: loading && servers.isEmpty
          ? _buildLoading(context)
          : error.isNotEmpty && servers.isEmpty
              ? _buildError(context)
              : _buildContent(context, isDark),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const AppLogo(size: 56),
        const SizedBox(height: 20),
        Text('Connecting to AWS...',
            style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context), fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
              color: AppColors.accent,
              backgroundColor: AppTheme.cardBorder(context)),
        ),
      ]),
    );
  }

  Widget _buildError(BuildContext context) {
    final cardColor = AppTheme.card(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.critical, size: 40),
            const SizedBox(height: 12),
            Text('Connection Failed',
                style: GoogleFonts.inter(
                    color: AppTheme.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(error,
                style: TextStyle(
                    color: AppTheme.textSecondary(context), fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);
    final cardColor   = AppTheme.card(context);
    final borderColor = AppTheme.cardBorder(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dashboard',
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('Overview of your cloud infrastructure',
                      style: TextStyle(color: textMuted, fontSize: 12)),
                ]),
                Row(children: [
                  if (_wsConnected)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Live',
                            style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
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
                      loadData();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
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
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: criticalCount > 0
                      ? [AppColors.critical, AppColors.warning]
                      : [AppColors.success, AppColors.accent],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Icon(
                  criticalCount > 0
                      ? Icons.warning_rounded
                      : Icons.verified_rounded,
                  color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    criticalCount > 0
                        ? '⚡ Auto-Healing Active — $criticalCount critical server(s) detected'
                        : '✅ All Systems Healthy — ${servers.length} servers running normally',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Text('${alerts.length} alerts',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _metricCard(context, 'Total Servers',
                  '${servers.length}', Icons.storage_rounded, AppColors.accent),
              const SizedBox(width: 12),
              _metricCard(context, 'Healthy',
                  '$healthyCount', Icons.check_circle_rounded, AppColors.success),
              const SizedBox(width: 12),
              _metricCard(context, 'Alerts',
                  '${alerts.length}', Icons.notifications_rounded, AppColors.warning),
              const SizedBox(width: 12),
              _metricCard(context, 'Critical',
                  '$criticalCount', Icons.dangerous_rounded, AppColors.critical),
            ]),
            const SizedBox(height: 20),
            _awsPanel(
              context,
              title: 'Server Metrics',
              icon: Icons.bar_chart_rounded,
              child: ServerChartsGrid(servers: servers),
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _awsPanel(
                context,
                title: 'Recent Alerts',
                icon: Icons.notifications_rounded,
                iconColor: AppColors.warning,
                child: Column(
                  children: alerts.take(3).map(
                    (alert) => _alertRow(context, alert)).toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _awsPanel(BuildContext context, {
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    final cardColor   = AppTheme.card(context);
    final borderColor = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(children: [
              Icon(icon, color: iconColor ?? AppColors.accent, size: 15),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.inter(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  Widget _metricCard(BuildContext context, String label,
      String value, IconData icon, Color color) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppTheme.card(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                Text(value,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.textMuted(context)
                      : const Color(0xFF4B5563),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Widget _alertRow(BuildContext context, dynamic alert) {
    final borderColor = AppTheme.cardBorder(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.warningGlow,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.warning_rounded,
              color: AppColors.warning, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert['message'] ?? 'Alert',
                  style: TextStyle(
                      color: AppTheme.textPrimary(context), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(
                '${alert['serverId'] ?? ''} · ${alert['severity'] ?? ''}',
                style: TextStyle(
                    color: AppTheme.textMuted(context), fontSize: 10),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Text(
            (alert['severity'] ?? 'WARN').toUpperCase(),
            style: const TextStyle(
                color: AppColors.warning,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }
}