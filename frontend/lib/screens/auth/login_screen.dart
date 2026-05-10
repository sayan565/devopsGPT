import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_background.dart';
import '../../services/api_service.dart';
import 'aws_connect_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  int _tabIndex = 0;

  final _signInEmailController    = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _usernameController       = TextEditingController();
  final _emailController          = TextEditingController();
  final _signUpPasswordController = TextEditingController();

  bool _isLoading      = false;
  bool _showSignInPass = false;
  bool _showSignUpPass = false;
  String _error        = '';
  String _success      = '';

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    setState(() {
      _tabIndex = index;
      _error    = '';
      _success  = '';
    });
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':      return 'No account found with this email.';
      case 'wrong-password':      return 'Incorrect password. Please try again.';
      case 'invalid-email':       return 'Please enter a valid email address.';
      case 'email-already-in-use':return 'An account already exists with this email.';
      case 'weak-password':       return 'Password must be at least 6 characters.';
      case 'too-many-requests':   return 'Too many attempts. Please try again later.';
      case 'network-request-failed': return 'Network error. Check your connection.';
      case 'invalid-credential':  return 'Invalid email or password.';
      default: return e.message ?? 'An error occurred. Please try again.';
    }
  }

  // ── Load Tenant ID after login ────────────────
  Future<void> _loadTenantId(String email) async {
    try {
      final result = await ApiService.getTenantByEmail(email);
      ApiService.currentTenantId = result['tenant_id'] ?? '';
      debugPrint('[Login] tenant_id loaded: ${ApiService.currentTenantId}');
    } catch (e) {
      ApiService.currentTenantId = '';
      debugPrint('[Login] No tenant found for $email, using default account');
    }
  }

  // ── Sign In ───────────────────────────────────
  Future<void> _login() async {
    final email = _signInEmailController.text.trim();
    final pass  = _signInPasswordController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() { _isLoading = true; _error = ''; });

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pass);
      await _loadTenantId(email);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _isLoading = false; _error = _friendlyError(e); });
    } catch (e) {
      setState(() { _isLoading = false; _error = 'An unexpected error occurred.'; });
    }
  }

  // ── Sign Up ───────────────────────────────────
  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final pass     = _signUpPasswordController.text.trim();

    if (username.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() { _isLoading = true; _error = ''; _success = ''; });

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: pass);
      await credential.user?.updateDisplayName(username);

      final uid = credential.user?.uid ?? '';
      String tenantId = '';

      // Register tenant with pending ARN — user will fill it in next screen
      try {
        final result = await ApiService.registerTenant(
          name: username,
          email: email,
          uid: uid,
        );
        tenantId = result['tenant_id'] ?? '';
        ApiService.currentTenantId = tenantId;
      } catch (e) {
        debugPrint('[SignUp] Tenant registration failed: $e');
      }

      setState(() { _isLoading = false; });

      if (mounted) {
        // Navigate to AWS connect onboarding screen
        Navigator.pushReplacementNamed(
          context,
          '/aws-connect',
          arguments: {
            'username': username,
            'email':    email,
            'uid':      uid,
            'tenantId': tenantId,
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() { _isLoading = false; _error = _friendlyError(e); });
    } catch (e) {
      setState(() { _isLoading = false; _error = 'An unexpected error occurred.'; });
    }
  }

  // ── Sign Up with Email (bottom sheet) ─────────
  void _signUpWithEmail() {
    final emailCtrl   = TextEditingController();
    final passCtrl    = TextEditingController();
    bool showPass     = false;
    String sheetError = '';
    bool sheetLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final textPrimary   = AppTheme.textPrimary(ctx);
          final textMuted     = AppTheme.textMuted(ctx);
          final textSecondary = AppTheme.textSecondary(ctx);
          final isDark  = Theme.of(ctx).brightness == Brightness.dark;
          final sheetBg = isDark ? const Color(0xFF0D1424) : Colors.white;
          final borderTop = isDark
              ? const Color(0x1AFFFFFF)
              : const Color(0x20000000);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: borderTop)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted(ctx).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: AppColors.primaryGradient),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.email_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Sign up with Email',
                          style: GoogleFonts.inter(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Enter your email and password',
                          style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
                    ]),
                  ]),
                  const SizedBox(height: 24),
                  Text('Email Address', style: TextStyle(color: textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  _inputContainer(ctx,
                    child: TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'john@example.com',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.email_rounded, color: AppColors.accent, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Password', style: TextStyle(color: textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  _inputContainer(ctx,
                    child: TextField(
                      controller: passCtrl,
                      obscureText: !showPass,
                      style: TextStyle(color: textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '••••••••••',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.lock_rounded, color: AppColors.accent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: textMuted, size: 20),
                          onPressed: () => setSheetState(() => showPass = !showPass),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (sheetError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _errorBanner(sheetError),
                  ],
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: sheetLoading ? null : () async {
                      final email = emailCtrl.text.trim();
                      final pass  = passCtrl.text.trim();
                      if (email.isEmpty || pass.isEmpty) {
                        setSheetState(() => sheetError = 'Please fill in all fields');
                        return;
                      }
                      setSheetState(() { sheetError = ''; sheetLoading = true; });
                      try {
                        await _auth.createUserWithEmailAndPassword(email: email, password: pass);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          setState(() { _success = 'Account created! You can now sign in.'; _tabIndex = 0; });
                        }
                      } on FirebaseAuthException catch (e) {
                        setSheetState(() { sheetLoading = false; sheetError = _friendlyError(e); });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: sheetLoading ? null : const LinearGradient(colors: AppColors.primaryGradient),
                        color: sheetLoading ? AppTheme.cardBorder(ctx) : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: sheetLoading ? null : [
                          BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: sheetLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Create Account', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inputContainer(BuildContext ctx, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.glassWhite(ctx),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder(ctx)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.primaryGradient),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 20),
                      Text('DevOpsGPT', style: GoogleFonts.inter(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
                      Text('AI Cloud Operations Platform', style: GoogleFonts.inter(color: textMuted, fontSize: 14)),
                      const SizedBox(height: 32),
                      GlassCard(
                        padding: const EdgeInsets.all(4),
                        borderRadius: 16,
                        child: Row(children: [_tabButton('Sign In', 0), _tabButton('Sign Up', 1)]),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                          child: _tabIndex == 0 ? _buildSignInForm(context) : _buildSignUpForm(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.lock_rounded, color: AppColors.success, size: 14),
                        const SizedBox(width: 6),
                        Text('Secured with Firebase Auth', style: GoogleFonts.inter(color: textMuted, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isActive ? const LinearGradient(colors: AppColors.primaryGradient) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: GoogleFonts.inter(
              color: isActive ? Colors.white : AppTheme.textMuted(context),
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

    return Column(
      key: const ValueKey('signin'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back', style: GoogleFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        Text('Sign in to your account', style: GoogleFonts.inter(color: textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        _buildField(context: context, controller: _signInEmailController, label: 'Email Address', hint: 'john@example.com', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildField(context: context, controller: _signInPasswordController, label: 'Password', hint: '••••••••••', icon: Icons.lock_rounded, isPassword: true, showPassword: _showSignInPass, onTogglePassword: () => setState(() => _showSignInPass = !_showSignInPass)),
        if (_error.isNotEmpty && _tabIndex == 0) ...[const SizedBox(height: 12), _errorBanner(_error)],
        if (_success.isNotEmpty && _tabIndex == 0) ...[const SizedBox(height: 12), _successBanner(_success)],
        const SizedBox(height: 24),
        _submitButton(context: context, label: 'Sign In', onTap: _login),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => _switchTab(1),
            child: RichText(text: TextSpan(
              text: "Don't have an account? ",
              style: GoogleFonts.inter(color: textMuted, fontSize: 13),
              children: [TextSpan(text: 'Sign Up', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold))],
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textMuted   = AppTheme.textMuted(context);

    return Column(
      key: const ValueKey('signup'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create account', style: GoogleFonts.inter(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        Text('Fill in your details to get started', style: GoogleFonts.inter(color: textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        _buildField(context: context, controller: _usernameController, label: 'Username', hint: 'johndoe', icon: Icons.person_rounded),
        const SizedBox(height: 16),
        _buildField(context: context, controller: _emailController, label: 'Email Address', hint: 'john@example.com', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _buildField(context: context, controller: _signUpPasswordController, label: 'Password', hint: '••••••••••', icon: Icons.lock_rounded, isPassword: true, showPassword: _showSignUpPass, onTogglePassword: () => setState(() => _showSignUpPass = !_showSignUpPass)),
        if (_error.isNotEmpty && _tabIndex == 1) ...[const SizedBox(height: 12), _errorBanner(_error)],
        if (_success.isNotEmpty && _tabIndex == 1) ...[const SizedBox(height: 12), _successBanner(_success)],
        const SizedBox(height: 24),
        _submitButton(context: context, label: 'Create Account', onTap: _signUp),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Divider(color: AppTheme.glassBorder(context), thickness: 1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13))),
          Expanded(child: Divider(color: AppTheme.glassBorder(context), thickness: 1)),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _isLoading ? null : _signUpWithEmail,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.glassWhite(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.email_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              Text('Sign up with Email', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => _switchTab(0),
            child: RichText(text: TextSpan(
              text: 'Already have an account? ',
              style: GoogleFonts.inter(color: textMuted, fontSize: 13),
              children: [TextSpan(text: 'Sign In', style: GoogleFonts.inter(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold))],
            )),
          ),
        ),
      ],
    );
  }

  Widget _submitButton({required BuildContext context, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: _isLoading ? null : const LinearGradient(colors: AppColors.primaryGradient),
          color: _isLoading ? AppTheme.cardBorder(context) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isLoading ? null : [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.criticalGlow, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.error_rounded, color: AppColors.critical, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.critical, fontSize: 13))),
      ]),
    );
  }

  Widget _successBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.successGlow, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.success, fontSize: 13))),
      ]),
    );
  }

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword            = false,
    bool showPassword          = false,
    VoidCallback? onTogglePassword,
  }) {
    final textColor     = AppTheme.textPrimary(context);
    final textMuted     = AppTheme.textMuted(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassWhite(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !showPassword,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor, fontSize: 14),
            onSubmitted: (_) => _tabIndex == 0 ? _login() : _signUp(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: textMuted, size: 20),
                      onPressed: onTogglePassword,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}