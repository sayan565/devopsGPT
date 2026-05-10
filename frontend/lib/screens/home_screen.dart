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
  int _currentIndex = 0;

  final _navItems = const [
    _NavItem(icon: Icons.dashboard_rounded,     label: 'Dashboard', gradient: [Color(0xFF00D4FF), Color(0xFF0099BB)]),
    _NavItem(icon: Icons.notifications_rounded, label: 'Alerts',    gradient: [Color(0xFFF59E0B), Color(0xFFD97706)]),
    _NavItem(icon: Icons.smart_toy_rounded,     label: 'AI',        gradient: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
    _NavItem(icon: Icons.storage_rounded,       label: 'Servers',   gradient: [Color(0xFF10B981), Color(0xFF059669)]),
    _NavItem(icon: Icons.list_alt_rounded,      label: 'Logs',      gradient: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
  ];

  final _screens = const [
    DashboardScreen(),
    AlertsScreen(),
    AIChatScreen(),
    InfrastructureScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = AppTheme.bg(context);
    final topBarBg    = isDark ? const Color(0xFF060B18) : const Color(0xFF0F172A);
    final navBarBg    = isDark ? const Color(0xFF0D1424) : const Color(0xFFFFFFFF);
    final borderColor = AppTheme.cardBorder(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [

          // ── Top Header ──────────────────────────────────
          Container(
            color: topBarBg,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const AppLogo(size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DevOpsGPT',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            )),
                        Text('Cloud Operations',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 9,
                              letterSpacing: 1.5,
                            )),
                      ],
                    ),

                    const Spacer(),

                    // Active page pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _navItems[_currentIndex]
                            .gradient[0]
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _navItems[_currentIndex]
                              .gradient[0]
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(children: [
                        Icon(_navItems[_currentIndex].icon,
                            color: _navItems[_currentIndex].gradient[0],
                            size: 12),
                        const SizedBox(width: 5),
                        Text(_navItems[_currentIndex].label,
                            style: TextStyle(
                              color: _navItems[_currentIndex].gradient[0],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                    ),

                    const SizedBox(width: 10),

                    // Theme toggle
                    GestureDetector(
                      onTap: () => themeNotifier.value =
                          isDark ? ThemeMode.light : ThemeMode.dark,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
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

          // ── Main content ────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _screens[_currentIndex],
              ),
            ),
          ),

          // ── Bottom Navigation Bar ────────────────────────
          Container(
            decoration: BoxDecoration(
              color: navBarBg,
              border: Border(top: BorderSide(color: borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_navItems.length, (i) {
                    final isActive = _currentIndex == i;
                    final item = _navItems[i];
                    return GestureDetector(
                      onTap: () => setState(() => _currentIndex = i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: isActive ? 16 : 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? LinearGradient(colors: item.gradient)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icon,
                                size: 20,
                                color: isActive
                                    ? Colors.white
                                    : AppTheme.textMuted(context)),
                            if (isActive) ...[
                              const SizedBox(width: 6),
                              Text(item.label,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
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
  final List<Color> gradient;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.gradient,
  });
}
