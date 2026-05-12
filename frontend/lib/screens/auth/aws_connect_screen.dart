import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/animated_background.dart';
import '../../services/api_service.dart';

class AwsConnectScreen extends StatefulWidget {
  final String username;
  final String email;
  final String uid;
  final String tenantId; // pre-created tenant_id from signup

  const AwsConnectScreen({
    super.key,
    required this.username,
    required this.email,
    required this.uid,
    required this.tenantId,
  });

  @override
  State<AwsConnectScreen> createState() => _AwsConnectScreenState();
}

class _AwsConnectScreenState extends State<AwsConnectScreen>
    with SingleTickerProviderStateMixin {
  final _arnController = TextEditingController();

  bool _step1Done  = false;
  bool _isLoading  = false;
  String _error    = '';
  String _success  = '';

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Master account ID — injected via --dart-define at build time ──────────
  // Never hardcode AWS account IDs in source code.
  // Set via: --dart-define=DEVOPSGPT_MASTER_ACCOUNT_ID=649536287899
  static const _masterAccountId = String.fromEnvironment(
    'DEVOPSGPT_MASTER_ACCOUNT_ID',
    defaultValue: '649536287899', // fallback for local dev only
  );

  String get _cfnUrl {
    final base = 'https://console.aws.amazon.com/cloudformation/home'
        '?region=us-east-1'
        '#/stacks/quickcreate'
        '?templateURL=https://devopsgpt-cfn-templates.s3.amazonaws.com/tenant_onboarding_role.yaml'
        '&stackName=DevOpsGPT-Monitor'
        '&param_DevOpsGPTMasterAccountId=$_masterAccountId'
        '&param_TenantId=${widget.tenantId}';
    return base;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _arnController.dispose();
    super.dispose();
  }

  Future<void> _openCloudFormation() async {
    final uri = Uri.parse(_cfnUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      setState(() => _step1Done = true);
    } else {
      // Fallback: copy URL to clipboard
      await Clipboard.setData(ClipboardData(text: _cfnUrl));
      setState(() => _step1Done = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'CloudFormation URL copied — paste it in your browser'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _connect() async {
    final arn = _arnController.text.trim();

    if (arn.isEmpty) {
      setState(() => _error = 'Please paste the Role ARN first');
      return;
    }
    if (!arn.startsWith('arn:aws:iam::')) {
      setState(() => _error = 'Invalid ARN format. Should start with arn:aws:iam::');
      return;
    }

    // Extract AWS account ID from ARN: arn:aws:iam::123456789012:role/...
    final parts        = arn.split(':');
    final awsAccountId = parts.length > 4 ? parts[4] : '';

    setState(() { _isLoading = true; _error = ''; });

    try {
      String tenantId = widget.tenantId;

      // If tenantId is empty (signup registration failed), register now
      if (tenantId.isEmpty) {
        final reg = await ApiService.registerTenant(
          name:  widget.username,
          email: widget.email,
          uid:   widget.uid,
        );
        tenantId = reg['tenant_id'] ?? '';
      }

      if (tenantId.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Could not create tenant account. Please try again.';
        });
        return;
      }

      await ApiService.updateTenantArn(
        tenantId:     tenantId,
        roleArn:      arn,
        awsAccountId: awsAccountId,
      );

      ApiService.currentTenantId = tenantId;

      setState(() { _isLoading = false; _success = 'AWS account connected!'; });

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Connection failed: ${e.toString()}';
      });
    }
  }

  void _skipForNow() {
    ApiService.currentTenantId = widget.tenantId;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header ──────────────────────────────
                    const SizedBox(height: 12),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: AppColors.primaryGradient),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.cloud_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome, ${widget.username}!',
                                style: GoogleFonts.inter(
                                  color: textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                )),
                            Text("Let's connect your AWS account",
                                style: GoogleFonts.inter(
                                    color: textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── Info banner ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This creates a read-only IAM role in your AWS account so DevOpsGPT can monitor your infrastructure. No write access is granted.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Step 1 ───────────────────────────────
                    _stepCard(
                      context: context,
                      step: 1,
                      isDone: _step1Done,
                      title: 'Deploy IAM Role to your AWS',
                      subtitle:
                          'Click the button below. It opens AWS CloudFormation and automatically creates the required role.',
                      child: GestureDetector(
                        onTap: _openCloudFormation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.primaryGradient),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.rocket_launch_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text('Deploy to My AWS',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Step 2 ───────────────────────────────
                    _stepCard(
                      context: context,
                      step: 2,
                      isDone: false,
                      title: 'Copy the Role ARN',
                      subtitle:
                          'After CloudFormation finishes, go to the Outputs tab and copy the value of RoleArn.',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0A1628)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.cardBorder(context)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.terminal_rounded,
                              color: AppColors.accent, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'arn:aws:iam::<your-account-id>:role/DevOpsGPTRole',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Step 3 ───────────────────────────────
                    _stepCard(
                      context: context,
                      step: 3,
                      isDone: _success.isNotEmpty,
                      title: 'Paste the Role ARN & Connect',
                      subtitle:
                          'Paste the ARN you copied from CloudFormation Outputs.',
                      child: Column(
                        children: [
                          // ARN input
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.glassWhite(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _error.isNotEmpty
                                      ? AppColors.critical.withValues(alpha: 0.5)
                                      : AppTheme.glassBorder(context)),
                            ),
                            child: TextField(
                              controller: _arnController,
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontFamily: 'monospace'),
                              onChanged: (_) {
                                if (_error.isNotEmpty) {
                                  setState(() => _error = '');
                                }
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'arn:aws:iam::123456789012:role/DevOpsGPTRole',
                                hintStyle: TextStyle(
                                    color: textMuted,
                                    fontSize: 12,
                                    fontFamily: 'monospace'),
                                prefixIcon: const Icon(Icons.vpn_key_rounded,
                                    color: AppColors.accent, size: 18),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_paste_rounded,
                                      color: AppColors.accent, size: 18),
                                  tooltip: 'Paste from clipboard',
                                  onPressed: () async {
                                    final data = await Clipboard.getData(
                                        Clipboard.kTextPlain);
                                    if (data?.text != null) {
                                      _arnController.text =
                                          data!.text!.trim();
                                    }
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),

                          if (_error.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.criticalGlow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_rounded,
                                    color: AppColors.critical, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error,
                                      style: const TextStyle(
                                          color: AppColors.critical,
                                          fontSize: 12)),
                                ),
                              ]),
                            ),
                          ],

                          if (_success.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.successGlow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 16),
                                const SizedBox(width: 8),
                                Text(_success,
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Connect button
                          GestureDetector(
                            onTap: _isLoading ? null : _connect,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669)
                                        ],
                                      ),
                                color: _isLoading
                                    ? AppTheme.cardBorder(context)
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.success
                                              .withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.check_circle_rounded,
                                              color: Colors.white,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text('Connect My AWS Account',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              )),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Skip link ────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _skipForNow,
                        child: Text(
                          'Skip for now — connect later in Settings',
                          style: GoogleFonts.inter(
                            color: textMuted,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: textMuted,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step card widget ─────────────────────────────────
  Widget _stepCard({
    required BuildContext context,
    required int step,
    required bool isDone,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final cardColor   = AppTheme.card(context);
    final borderColor = isDone
        ? AppColors.success.withValues(alpha: 0.4)
        : AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isDone ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Step number / done indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: isDone
                    ? const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)])
                    : const LinearGradient(
                        colors: AppColors.primaryGradient),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : Text('$step',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: textMuted, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
