import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'core/providers/app_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';
import 'screens/corridor/activate_corridor_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/registration/registration_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Notification service (FCM + local) — Android/iOS only
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(const AstraApp());
}

class AstraApp extends StatelessWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        title: 'ASTRA',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _SplashRouter(),
        routes: {
          '/register': (_) => const RegistrationScreen(),
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/activate': (_) => const ActivateCorridorScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.primary,
      ),
      textTheme: TextTheme(
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.bodySmall,
        headlineLarge: AppTextStyles.display,
        headlineMedium: AppTextStyles.h1,
        headlineSmall: AppTextStyles.h2,
        titleLarge: AppTextStyles.h3,
        labelSmall: AppTextStyles.caption,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleTextStyle: AppTextStyles.h3,
        iconTheme: const IconThemeData(color: AppColors.textSecond),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          textStyle: AppTextStyles.button,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ── Splash / Router ────────────────────────────────────────────────────────────

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6)),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    _determineStartScreen();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _determineStartScreen() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final authService = AuthService();
    final firestoreService = FirestoreService();

    // Check for stored driver ID
    final driverId = await authService.getStoredDriverId();
    if (driverId != null && driverId.isNotEmpty) {
      final driver = await firestoreService.getDriver(driverId);
      if (driver != null && mounted) {
        // Update FCM token silently (not supported on web)
        String? fcmToken;
        if (!kIsWeb) {
          fcmToken = await NotificationService().getFcmToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await firestoreService.updateFcmToken(driverId, fcmToken);
          }
        }
        if (mounted) {
          context.read<AppProvider>().setDriver(
                fcmToken != null ? driver.copyWith(fcmToken: fcmToken) : driver,
              );
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }
    }

    // No session — go to login
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.primaryGlow,
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emergency,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ASTRA',
                    style: AppTextStyles.display.copyWith(
                      color: AppColors.primary,
                      fontSize: 44,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ADAPTIVE SIGNAL TRAFFIC RESPONSE',
                    style: AppTextStyles.caption.copyWith(
                      letterSpacing: 3,
                      color: AppColors.textSecond,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
