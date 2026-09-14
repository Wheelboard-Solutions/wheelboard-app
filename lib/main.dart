import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_environment.dart';
import 'core/storage/secure_session_manager.dart';
import 'core/network/api_client.dart';
import 'core/auth/auth_service.dart';
import 'core/navigation/app_routes.dart';
import 'core/navigation/app_pages.dart';
import 'core/localization/localization_service.dart';
import 'core/localization/app_translations.dart';
import 'services/push_notification_service.dart';
import 'utils/navigation_helper.dart';
import 'utils/app_logger.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  AppLogger.d("🔐 Environment variables loaded successfully");

  // Push notifications (FCM). No-ops gracefully until native config is added.
  await PushNotificationService.instance.init();

  // Initialize Localization Service
  await Get.putAsync(() => LocalizationService.init());
  AppLogger.d("🌐 Localization Service initialized");

  // ── Initialize Core Services ─────────────────────────────────────────
  // API_URL is read from .env — no code change needed to switch environments.
  AppLogger.i("🌐 API Base URL: ${AppEnvironment.apiBaseUrl}");

  final sessionManager = SecureSessionManager();
  ApiClient.init(baseUrl: ApiConstants.baseUrl, sessionManager: sessionManager);

  // Register the single AuthService (core, no legacy shim)
  Get.put(AuthService(storage: sessionManager));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService.to;

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WheelBoard',
      themeMode: ThemeMode.system,
      translations: AppTranslations(),
      locale: localizationService.currentLocale,
      fallbackLocale: LocalizationService.fallbackLocale,
      supportedLocales: LocalizationService.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      unknownRoute: GetPage(
        name: '/not-found',
        page: () => Scaffold(
          body: Center(child: Text('Page not found'.tr)),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _bgController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _bgScale;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bgScale = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeOut),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    _checkSession();
  }

  Future<void> _checkSession() async {
    final auth = AuthService.to;
    await auth.initialize();

    final loggedIn = auth.isLoggedIn;
    AppLogger.d("🔐 Is Logged In: $loggedIn | Role: ${auth.userRole.value}");

    if (loggedIn) {
      // Register this device's FCM token for the already-logged-in user.
      PushNotificationService.instance.registerForCurrentUser();
    }

    if (!mounted) return;
    if (!loggedIn) {
      Get.offAllNamed(AppRoutes.onboarding);
    } else {
      NavigationHelper.navigateToMainWrapper();
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgController, _logoController, _textController]),
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF36969),
                  Color(0xFFE85555),
                  Color(0xFFFF8A8A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  top: -size.width * 0.3,
                  right: -size.width * 0.2,
                  child: Transform.scale(
                    scale: _bgScale.value,
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -size.width * 0.25,
                  left: -size.width * 0.15,
                  child: Container(
                    width: size.width * 0.6,
                    height: size.width * 0.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.15,
                  right: size.width * 0.05,
                  child: Container(
                    width: size.width * 0.25,
                    height: size.width * 0.25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),

                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoOpacity,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              'assets/mainlogo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_shipping_rounded,
                                size: 64,
                                color: Color(0xFFF36969),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // App name
                      FadeTransition(
                        opacity: _textOpacity,
                        child: SlideTransition(
                          position: _textSlide,
                          child: const Text(
                            'WHEELBOARD',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 4,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline
                      FadeTransition(
                        opacity: _taglineOpacity,
                        child: SlideTransition(
                          position: _taglineSlide,
                          child: Text(
                            'Fleet. Jobs. Services.',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 2,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom loader
                Positioned(
                  bottom: 56,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _taglineOpacity,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Getting things ready...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontFamily: 'Poppins',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
