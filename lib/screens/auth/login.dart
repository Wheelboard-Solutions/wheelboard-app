import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/Transport/login_controller.dart';
import '../../core/auth/auth_service.dart' as core;
import '../../core/auth/user_role.dart';
import '../../utils/navigation_helper.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/legal_widgets.dart';
import '../CompanyTransport/complete_company_profile.dart';
import '../CompanyServiceProvider/complete_profile_screen.dart';
import '../../widgets/language_selection_bottom_sheet.dart';
import '../../core/localization/localization_service.dart';
import 'onboarding_screen.dart';
import 'forgot_password.dart';


// ─── Constants ────────────────────────────────────────────────────────────

const _primary = Color(0xFFF36969);
const _textDark = Color(0xFF1A1C1E);
const _textGrey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);
const _inputBg = Color(0xFFF9FAFB);

// ─── LoginScreen ──────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final LoginController _ctrl = Get.put(LoginController());

  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      _ctrl.resetOTP();
      _otpCtrl.clear();
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Auth actions ─────────────────────────────────────────────────────────

  Future<void> _loginWithPassword() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty) { SnackBarHelper.error('Please enter email or phone'); return; }
    if (pass.isEmpty) { SnackBarHelper.error('Please enter password'); return; }
    final resp = await _ctrl.login(email, pass);
    if (resp != null) _handleAuthSuccess(resp.user.role);
  }

  Future<void> _sendOtp() async {
    await _ctrl.sendOTP(_phoneCtrl.text.trim());
  }

  Future<void> _loginWithOtp() async {
    final resp = await _ctrl.loginWithOTP(
      _phoneCtrl.text.trim(),
      _otpCtrl.text.trim(),
    );
    if (resp != null) _handleAuthSuccess(resp.user.role);
  }

  Future<void> _handleAuthSuccess(UserRole role) async {
    final authUser = core.AuthService.to.currentUser.value;
    final profileComplete = authUser?.isProfileComplete ?? true;

    if (role == UserRole.company && !profileComplete) {
      Get.to(() => const CompanyCompleteProfile());
      return;
    }
    if (role == UserRole.business && !profileComplete) {
      Get.to(() => const ServiceProviderCompleteProfileScreen());
      return;
    }
    NavigationHelper.navigateToMainWrapper();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  //
  // Architecture:
  //   Scaffold(bg: coral) → Column
  //     ├── _buildHeader()   SafeArea(bottom:false) + padding + content  [intrinsic height]
  //     └── Expanded
  //         └── _buildCard() Container(rounded-top) → SafeArea(top:false) → Column
  //                            ├── TabBar               [fixed 48px]
  //                            └── Expanded(TabBarView) [fills bounded remainder]
  //                                └── each tab: SingleChildScrollView → Column
  //
  // This gives TabBarView a finite bounded height without IntrinsicHeight or
  // nested ScrollViews, satisfying RenderViewport's bounded-height requirement.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primary,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCard()),
          ],
        ),
      ),
    );
  }

  // ── Header (coral background from Scaffold) ───────────────────────────────

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.canPop(context)
                      ? Navigator.pop(context)
                      : Get.offAll(() => const OnboardingScreen(), transition: Transition.fadeIn),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                GestureDetector(
                  onTap: () => LanguageSelectionBottomSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.language, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          LocalizationService.to.currentLanguageName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/mainlogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_shipping_rounded,
                      color: _primary,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'WHEELBOARD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome back'.tr,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFamily: 'Poppins',
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to continue to your account'.tr,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85),
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card (fills remaining bounded height from Expanded above) ────────────

  Widget _buildCard() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // SafeArea(top:false) handles home-indicator / nav-bar padding at bottom.
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab selector — fixed height, no flex
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: _textGrey,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                  tabs: [
                    Tab(text: 'Email & Password'.tr),
                    Tab(text: 'Phone OTP'.tr),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // TabBarView — fills remaining bounded height.
            // Parent Column has bounded height (Scaffold → Column → Expanded → Container → SafeArea → Column).
            // This satisfies RenderViewport's finite-constraints requirement.
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPasswordTab(),
                  _buildOtpTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password tab ─────────────────────────────────────────────────────────
  // SingleChildScrollView scrolls when keyboard is shown (resizeToAvoidBottomInset
  // shrinks Scaffold body, Expanded shrinks TabBarView, tab scrolls to focused field).

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            label: 'Email or Phone',
            hint: 'Enter your email or phone number',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 16),
          Obx(() => _field(
            label: 'Password',
            hint: 'Enter your password',
            controller: _passCtrl,
            obscure: _ctrl.obscurePassword.value,
            prefixIcon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _ctrl.obscurePassword.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: _textGrey,
              ),
              onPressed: _ctrl.togglePasswordVisibility,
              splashRadius: 18,
            ),
          )),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Get.to(() => const ForgotPasswordScreen()),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => _primaryButton(
            label: 'Sign In'.tr,
            loading: _ctrl.isLoading.value,
            onTap: _loginWithPassword,
          )),

          const SizedBox(height: 16),
          legalLoginNotice(),
          const SizedBox(height: 16),
          _signUpRow(),
          if (kDebugMode) _buildDebugLogins(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── OTP tab ──────────────────────────────────────────────────────────────

  Widget _buildOtpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Obx(() {
        final otpSent = _ctrl.isOTPSent.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              label: 'Phone Number',
              hint: 'Enter 10-digit mobile number',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              readOnly: otpSent,
              suffix: otpSent
                  ? TextButton(
                      onPressed: () {
                        _ctrl.resetOTP();
                        _otpCtrl.clear();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    )
                  : null,
            ),
            if (otpSent) ...[
              const SizedBox(height: 16),
              _field(
                label: 'Enter OTP',
                hint: '6-digit OTP sent to your phone',
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.pin_outlined,
                maxLength: 6,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _ctrl.sendOTP(_phoneCtrl.text.trim()),
                  style: TextButton.styleFrom(
                    foregroundColor: _textGrey,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Resend OTP'.tr,
                    style: const TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _primaryButton(
              label: otpSent ? 'Verify OTP'.tr : 'Send OTP'.tr,
              loading: _ctrl.isLoading.value,
              onTap: otpSent ? _loginWithOtp : _sendOtp,
            ),

            const SizedBox(height: 24),
            _signUpRow(),
            const SizedBox(height: 8),
          ],
        );
      }),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    bool readOnly = false,
    IconData? prefixIcon,
    Widget? suffix,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textDark,
            fontFamily: 'Poppins',
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF3F4F6) : _inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            readOnly: readOnly,
            maxLength: maxLength,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: readOnly ? _textGrey : _textDark,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB0B7C3),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
              ),
              counterText: '',
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 18, color: _textGrey)
                  : null,
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
      ),
    );
  }

  Widget _signUpRow() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account?".tr,
            style: const TextStyle(fontSize: 13, color: _textGrey, fontFamily: 'Poppins'),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Get.to(
              () => const OnboardingScreen(),
              transition: Transition.rightToLeft,
            ),
            child: Text(
              'Sign Up'.tr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _primary,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],

      ),
    );
  }

  Widget _buildDebugLogins() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Quick Test Logins',
          style: TextStyle(fontSize: 11, color: _textGrey, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _debugBtn('Transport', () {
              _tabController.animateTo(1);
              _phoneCtrl.text = '8600202678';
              _ctrl.sendOTP('8600202678');
            })),
            const SizedBox(width: 6),
            Expanded(child: _debugBtn('Professional', () {
              _tabController.animateTo(1);
              _phoneCtrl.text = '7420861942';
              _ctrl.sendOTP('7420861942');
            })),
            const SizedBox(width: 6),
            Expanded(child: _debugBtn('Service', () {
              _tabController.animateTo(1);
              _phoneCtrl.text = '8210447299';
              _ctrl.sendOTP('8210447299');
            })),
          ],
        ),
      ],
    );
  }

  Widget _debugBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: FittedBox(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}
