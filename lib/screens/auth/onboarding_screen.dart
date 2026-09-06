import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

// Assuming these are your external imports
import 'login.dart';
import 'company_signup.dart';
import 'professional_signup.dart';
import 'service_provider_register_screen.dart';

/// ----------------------------------------------------------------------------
/// DESIGN SYSTEM & THEME
/// ----------------------------------------------------------------------------
class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFFF36969);
  static const Color primaryDark = Color(0xFFD65858);
  static const Color primaryLight = Color(0xFFFFF1F1);

  // Surface & Background
  static const Color background = Color(0xFFF8FAFC); // Cool off-white
  static const Color surface = Colors.white;

  // Typography Colors
  static const Color textDark = Color(0xFF0F172A); // Slate 900
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Structural Colors
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color iconBgBase = Color(0xFFF1F5F9); // Slate 100

  // Font
  static const String font = 'Poppins';

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static final List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> glowShadow = [
    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Border Radii Constants
  static final BorderRadius radiusSm = BorderRadius.circular(12);
  static final BorderRadius radiusMd = BorderRadius.circular(16);
  static final BorderRadius radiusLg = BorderRadius.circular(24);

  // Typography Styles
  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    color: textDark,
    fontFamily: font,
    letterSpacing: -1.2,
    height: 1.1,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textDark,
    fontFamily: font,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textDark,
    fontFamily: font,
    letterSpacing: -0.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: textMuted,
    fontFamily: font,
    height: 1.6,
    letterSpacing: 0.1,
  );
}

/// ----------------------------------------------------------------------------
/// MAIN ONBOARDING SCREEN
/// ----------------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isSelectingRole = false;

  void _toggleView() {
    HapticFeedback.lightImpact();
    setState(() => _isSelectingRole = !_isSelectingRole);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.03),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _isSelectingRole
                  ? _RoleSelectionView(
                key: const ValueKey('RoleSelection'),
                onBack: _toggleView,
              )
                  : _WelcomeView(
                key: const ValueKey('Welcome'),
                onGetStarted: _toggleView,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// WELCOME VIEW (Dashboard/Hero)
/// ----------------------------------------------------------------------------
class _WelcomeView extends StatelessWidget {
  final VoidCallback onGetStarted;

  const _WelcomeView({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        _buildTypography(),
                        const SizedBox(height: 30),
                        _buildBentoGrid(),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 48.0, bottom: 36.0),
                      child: _GradientButton(
                        text: 'Get Started',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: onGetStarted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: AppTheme.radiusSm,
            boxShadow: AppTheme.subtleShadow,
            border: Border.all(color: AppTheme.border.withOpacity(0.5)),
          ),
          child: Image.asset(
            'assets/mainlogo.png',
            width: 24,
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_shipping_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Text(
          'Wheelboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
            letterSpacing: -0.5,
            fontFamily: AppTheme.font,
          ),
        ),
      ],
    );
  }

  Widget _buildTypography() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: AppTheme.display,
            children: [
              TextSpan(text: 'Everything\nYou Need,\n'),
              TextSpan(
                text: 'On The Road.',
                style: TextStyle(color: AppTheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Manage your fleet, discover lucrative jobs, and connect with trusted transport services—all in one unified platform.',
          style: AppTheme.body,
        ),
      ],
    );
  }

  Widget _buildBentoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BentoFeatureCard(
                title: 'Fleet',
                subtitle: 'Track vehicles',
                icon: Icons.local_shipping_rounded,
                iconBg: const Color(0xFFF0F9FF), // Sky 50
                iconColor: const Color(0xFF0EA5E9), // Sky 500
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _BentoFeatureCard(
                title: 'Jobs',
                subtitle: 'Discover & bid',
                icon: Icons.work_rounded,
                iconBg: const Color(0xFFFEFCE8), // Yellow 50
                iconColor: const Color(0xFFEAB308), // Yellow 500
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _BentoFeatureCard(
          title: 'Trusted Services',
          subtitle: 'Access top-rated garages and workshops instantly.',
          icon: Icons.build_circle_rounded,
          iconBg: AppTheme.primaryLight,
          iconColor: AppTheme.primary,
          isWide: true,
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// ROLE SELECTION VIEW
/// ----------------------------------------------------------------------------
class _RoleSelectionView extends StatelessWidget {
  final VoidCallback onBack;

  const _RoleSelectionView({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAppBar(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text('Join as', style: AppTheme.heading),
                Text(
                  'Who are you?',
                  style: AppTheme.heading.copyWith(color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select your role to tailor your platform experience to your specific needs.',
                  style: AppTheme.body,
                ),
                const SizedBox(height: 40),

                _RoleOptionCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Professional',
                  subtitle: 'Driver, Technician, or Helper',
                  onTap: () => Get.to(() => const ProfessionalRegisterScreen(),
                      transition: Transition.cupertino),
                ),
                const SizedBox(height: 16),
                _RoleOptionCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Transport Company',
                  subtitle: 'Fleet owner managing trips',
                  onTap: () => Get.to(() => Signup(initialCategory: 'Transport'),
                      transition: Transition.cupertino),
                ),
                const SizedBox(height: 16),
                _RoleOptionCard(
                  icon: Icons.storefront_outlined,
                  title: 'Service Provider',
                  subtitle: 'Garage, workshop, or dealer',
                  onTap: () => Get.to(() => const ServiceProviderRegisterScreen(),
                      transition: Transition.cupertino),
                ),

                const SizedBox(height: 56),
                _buildLoginPrompt(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 24, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textDark,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account?', style: AppTheme.body),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Get.to(() => const LoginScreen(), transition: Transition.fadeIn),
          child: const Text(
            'Log In',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              fontFamily: AppTheme.font,
            ),
          ),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// PROFESSIONAL REUSABLE COMPONENTS
/// ----------------------------------------------------------------------------

class _BentoFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool isWide;

  const _BentoFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.border, width: 1.5),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: isWide
          ? Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(child: _buildText()),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(),
          const SizedBox(height: 12),
          _buildText(),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: AppTheme.radiusMd,
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }

  Widget _buildText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.title.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontFamily: AppTheme.font,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.radiusLg,
        border: Border.all(color: AppTheme.border, width: 1.5),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppTheme.radiusLg,
          onTap: onTap,
          highlightColor: AppTheme.primaryLight.withOpacity(0.3),
          splashColor: AppTheme.primaryLight.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.title),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          fontFamily: AppTheme.font,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.border,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.radiusMd,
        boxShadow: AppTheme.glowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppTheme.radiusMd,
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: AppTheme.font,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 22, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingScreen();
}