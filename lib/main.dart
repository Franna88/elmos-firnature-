import 'package:elmos_app/data/services/auth_service.dart';
import 'package:elmos_app/data/services/sop_service.dart';
import 'package:elmos_app/data/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'utils/deep_link_handler.dart';
// import 'package:firebase_core/firebase_core.dart';

// Screens
// import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/templates/templates_screen.dart';
import 'presentation/screens/sop_editor/sop_editor_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
// import 'presentation/screens/recipe_screen.dart';

// Services and Models
import 'core/theme/app_theme.dart';
// import 'data/services/database_service.dart';
// import 'data/services/storage_service.dart';
// import 'utils/app_router.dart';
// import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Skip Firebase initialization and use fallback authentication
  // Try using the app with fallback authentication only
  
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
            previous ?? AnalyticsService(
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

  // For demo purposes: Test email link handling
  void _testEmailLinkHandling() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait until the app is fully loaded, then test the handler
      Future.delayed(const Duration(seconds: 2), () {
        if (context.mounted) {
          // Simulate an email link coming in
          const testLink = 'https://www.example.com/finishSignUp?cartId=1234&signIn=true';
          DeepLinkHandler.handleLink(context, testLink);
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    // Uncomment the line below to test email link handling
    // _testEmailLinkHandling();
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
      ],
      redirect: (context, state) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final isLoggedIn = authService.isLoggedIn;
        
        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToRegister = state.matchedLocation == '/register';
        
        // If not logged in and not going to login or register, redirect to login
        if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister) {
          return '/login';
        }
        
        // If logged in and going to login or register, redirect to dashboard
        if (isLoggedIn && (isGoingToLogin || isGoingToRegister)) {
          return '/';
        }
        
        return null;
      },
    );

    return MaterialApp.router(
      title: 'SOP Management System',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
