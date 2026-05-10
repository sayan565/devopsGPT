import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard/dashboard_screen.dart';
import 'alerts/alerts_screen.dart';
import 'ai/ai_chat_screen.dart';
import 'infrastructure/infrastructure_screen.dart';
import 'logs/logs_screen.dart';
import '../core/theme/app_colors.dart';
import '../widgets/app_logo.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded,       label: 'Dashboard',      short: 'Home'),
    _NavItem(icon: Icons.notifications_rounded,   label: 'Alerts',         short: 'Alerts'),
    _NavItem(icon: Icons.smart_toy_rounded,       label: 'AI Assistant',   short: 'AI'),
    _NavItem(icon: Icons.storage_rounded,         label: 'EC2 Instances',  short: 'Servers'),
    _NavItem(icon: Icons.list_alt_rounded,        label: 'CloudWatch Logs',short: 'Logs'),
  ];

  final screens = const [
    DashboardScreen(),
    AlertsScreen(),
    AIChatScreen(),
    InfrastructureScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textMuted   = AppTheme.textMuted(context);
    final bgColor     = AppTheme.bg(context);
    final borderColor = AppTheme.cardBorder(context);

    // AWS Console top bar colors
    final topBarBg = isDark
        ? const Color(0xFF0D1424)
        : const Color(0xFF232F3E); // AWS dark navy always

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [

          // ── AWS-style Top Navigation Bar ──────────
          Container(
            color: topBarBg,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // Logo + Brand
                    const AppLogo(size: 28),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DevOpsGPT',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            )),
                        Text('Console',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 9,
                              letterSpacing: 1.2,
                            )),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // Breadcrumb: Services > Current
                    Expanded(
                      child: Row(
                        children: [
                          Text('Services',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.chevron_right,
                                color: Colors.white38, size: 14),
                          ),
                          Flexible(
                            child: Text(
                              _navItems[currentIndex].label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Theme toggle
                    GestureDetector(
                      onTap: () {
                        themeNotifier.value = isDark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: isDark
                              ? const Color(0xFFF59E0B)
                              : Colors.white70,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── AWS-style Service Navigation Bar ─────
          Container(
            color: isDark
                ? const Color(0xFF0A1628)
                : const Color(0xFF1A2332),
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, i) {
                final isActive = currentIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => currentIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: isActive
                          ? Border.all(
                              color: AppColors.accent
                                  .withValues(alpha: 0.6),
                              width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _navItems[i].icon,
                          size: 13,
                          color: isActive
                              ? AppColors.accent
                              : Colors.white54,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _navItems[i].short,
                          style: TextStyle(
                            color: isActive
                                ? AppColors.accent
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Page breadcrumb strip ─────────────────
          Container(
            color: isDark
                ? const Color(0xFF060B18)
                : const Color(0xFFF8F9FA),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.home_rounded,
                    size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
                Text('DevOpsGPT',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 11)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right,
                      size: 12, color: textMuted),
                ),
                Text(_navItems[currentIndex].label,
                    style: TextStyle(
                        color: textMuted, fontSize: 11)),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────
          Divider(height: 1, color: borderColor),

          // ── Main Content ──────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey(currentIndex),
                child: screens[currentIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String short;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.short,
  });
}
