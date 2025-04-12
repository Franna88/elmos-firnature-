import 'package:elmos_app/data/services/auth_service.dart';
import 'package:elmos_app/data/services/sop_service.dart';
import 'package:elmos_app/data/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'utils/deep_link_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/populate_firebase.dart';

// Screens
// import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/create_profile_screen.dart';
import 'presentation/screens/auth/register_company_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/templates/templates_screen.dart';
import 'presentation/screens/sop_editor/sop_editor_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/sops/sops_screen.dart';
// import 'presentation/screens/recipe_screen.dart';

// Services and Models
import 'core/theme/app_theme.dart';
// import 'data/services/database_service.dart';
// import 'data/services/storage_service.dart';
// import 'utils/app_router.dart';
// import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('Firebase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing Firebase: $e');
      print('The app will run in local data mode');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SOPService()),
        ChangeNotifierProxyProvider2<AuthService, SOPService, AnalyticsService>(
          create: (context) => AnalyticsService(
            sopService: Provider.of<SOPService>(context, listen: false),
            authService: Provider.of<AuthService>(context, listen: false),
          ),
          update: (context, authService, sopService, previous) =>
              previous ??
              AnalyticsService(
                sopService: sopService,
                authService: authService,
              ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _initialLoginAttempted = false;

  // For demo purposes: Test email link handling
  void _testEmailLinkHandling() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait until the app is fully loaded, then test the handler
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          // Simulate an email link coming in
          const testLink =
              'https://www.example.com/finishSignUp?cartId=1234&signIn=true';
          DeepLinkHandler.handleLink(context, testLink);
        }
      });
    });
  }

  // Auto login for development convenience
  void _attemptAutoLogin() {
    if (_initialLoginAttempted) return;

    _initialLoginAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Delay slightly to allow the app to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      if (!context.mounted) return;

      final authService = Provider.of<AuthService>(context, listen: false);

      // If user is not logged in, attempt auto-login with default credentials
      if (!authService.isLoggedIn) {
        // Use the default admin credentials
        await authService.autoLogin();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Uncomment the line below to test email link handling
    // _testEmailLinkHandling();

    // Auto login for development
    _attemptAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/create-profile',
          builder: (context, state) => const CreateProfileScreen(),
        ),
        GoRoute(
          path: '/register-company',
          builder: (context, state) => const RegisterCompanyScreen(),
        ),
        GoRoute(
          path: '/templates',
          builder: (context, state) => const TemplatesScreen(),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'];
            return SOPEditorScreen(sopId: id ?? '');
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/sops',
          builder: (context, state) => const SOPsScreen(),
        ),
      ],
      redirect: (context, state) async {
        final authService = Provider.of<AuthService>(context, listen: false);
        final bool isLoggedIn = authService.isLoggedIn;

        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToRegister = state.matchedLocation == '/register';
        final isGoingToCreateProfile =
            state.matchedLocation == '/create-profile';
        final isGoingToRegisterCompany =
            state.matchedLocation == '/register-company';
        final isAuthRelatedRoute = isGoingToLogin ||
            isGoingToRegister ||
            isGoingToCreateProfile ||
            isGoingToRegisterCompany;

        // If going to register, don't redirect regardless of login state
        if (isGoingToRegister) {
          return null; // Allow access to register page
        }

        // Important: Always return null for login page when not logged in
        // to prevent redirect loops
        if (isGoingToLogin && !isLoggedIn) {
          return null; // Stay on login page if not logged in
        }

        // In debug mode, try auto-login when heading to login page
        if (kDebugMode && isGoingToLogin && !isLoggedIn) {
          // Auto-login with development credentials
          final success = await authService.autoLogin();
          if (success) {
            return '/'; // Go to dashboard if auto-login succeeded
          }
        }

        // If not logged in and not going to auth routes, redirect to login
        if (!isLoggedIn && !isAuthRelatedRoute) {
          return '/login';
        }

        // If logged in and going to auth routes, redirect to dashboard
        // But don't redirect from register page
        if (isLoggedIn && isAuthRelatedRoute && !isGoingToRegister) {
          return '/';
        }

        return null;
      },
    );

    return MaterialApp.router(
      title: 'SOP Management System',
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
