import 'package:elmos_furniture_app/data/services/auth_service.dart';
import 'package:elmos_furniture_app/data/services/sop_service.dart';
import 'package:elmos_furniture_app/data/services/analytics_service.dart';
import 'package:elmos_furniture_app/data/services/category_service.dart';
import 'package:elmos_furniture_app/data/services/mes_service.dart';
import 'package:elmos_furniture_app/data/services/user_management_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'utils/deep_link_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'util/setup_services.dart';

// Screens
// import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/create_profile_screen.dart';
import 'presentation/screens/auth/register_company_screen.dart';

import 'presentation/screens/categories/categories_screen.dart';
import 'presentation/screens/sop_editor/sop_editor_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/sops/sops_screen.dart';

import 'presentation/screens/mobile/mobile_sop_viewer_screen.dart';
import 'presentation/screens/mobile/mobile_categories_screen.dart';
import 'presentation/screens/mobile/mobile_sops_screen.dart';
import 'presentation/screens/mobile/mobile_login_screen.dart';
import 'presentation/screens/mobile/mobile_sop_editor_screen.dart';
import 'presentation/screens/mobile/mobile_selection_screen.dart';
import 'presentation/screens/image_upload_test_screen.dart';
import 'presentation/screens/mes/mes_screen.dart';
import 'presentation/screens/mes_management_screen.dart';
import 'presentation/screens/mes_reports_screen.dart';
import 'presentation/screens/user_management/user_management_screen.dart';
import 'mes_tablet/models/user.dart';
import 'mes_tablet/screens/process_selection_screen.dart';
// import 'presentation/screens/recipe_screen.dart';

// Services and Models
import 'core/theme/app_theme.dart';
// import 'data/services/database_service.dart';
// import 'data/services/storage_service.dart';
// import 'utils/app_router.dart';
// import 'utils/constants.dart';

void main() async {
  debugPrint('🚀 APP: Starting application...');
  WidgetsFlutterBinding.ensureInitialized();

  // Configure URL strategy for Flutter web - ESSENTIAL for proper URL handling
  if (kIsWeb) {
    usePathUrlStrategy();
    debugPrint('🌐 APP: Configured path URL strategy for web');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('🔥 APP: Firebase initialized successfully');
  debugPrint(
      'Firebase project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}');

  // Initialize services
  debugPrint('🔧 APP: Setting up services...');
  setupServices();
  debugPrint('🔧 APP: Services setup complete');

  debugPrint('🎬 APP: Running MyApp...');
  runApp(const MyApp());
  debugPrint('✅ APP: Firebase initialized successfully');
  debugPrint(
      'Firebase project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ MYAPP: Building MyApp widget...');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => SOPService()),
        ChangeNotifierProvider(create: (context) => CategoryService()),
        ChangeNotifierProvider(create: (context) => MESService()),
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
        ChangeNotifierProxyProvider<AuthService, UserManagementService>(
          create: (context) => UserManagementService(
            Provider.of<AuthService>(context, listen: false),
          ),
          update: (context, authService, previous) =>
              previous ?? UserManagementService(authService),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
          debugPrint(
              '🔄 MYAPP: Consumer<AuthService> rebuilding - isLoggedIn: ${authService.isLoggedIn}');
          debugPrint('🔄 MYAPP: Creating router with authService...');
          return MaterialApp.router(
            title: "Elmo's Furniture SOP Manager",
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            routerConfig: _createRouter(authService),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthService authService) {
    debugPrint('🛣️ ROUTER: Creating GoRouter...');
    debugPrint(
        '🛣️ ROUTER: Initial auth state - isLoggedIn: ${authService.isLoggedIn}, userEmail: ${authService.userEmail}');

    return GoRouter(
      initialLocation: Uri.base.path,
      redirect: (context, state) {
        final bool isLoggedIn = authService.isLoggedIn;
        final bool isInitialized = authService.isInitialized;
        final bool isLoginRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/mobile/login';
        final bool isRegisterRoute = state.matchedLocation == '/register';

        // Check if the user is on a mobile device
        final bool isMobileDevice = _isMobileDevice(context);

        // Add comprehensive logging for debugging
        debugPrint('🔄 ROUTER REDIRECT DEBUG:');
        debugPrint('  📍 Current location: ${state.matchedLocation}');
        debugPrint('  🔐 Is logged in: $isLoggedIn');
        debugPrint('  ⚙️ Is initialized: $isInitialized');
        debugPrint('  📱 Is mobile device: $isMobileDevice');
        debugPrint('  🚪 Is login route: $isLoginRoute');
        debugPrint('  📝 Is register route: $isRegisterRoute');
        debugPrint('  👤 User email: ${authService.userEmail}');
        debugPrint('  🆔 User ID: ${authService.userId}');

        // If AuthService is not yet initialized, don't redirect yet
        if (!isInitialized) {
          debugPrint('  ⏳ AuthService not initialized yet, waiting...');
          return null;
        }

        // Special case: Allow direct access to specific SOPs via mobile web (for QR code scanning)
        // This bypasses authentication for mobile SOP viewer when accessed directly
        if (state.matchedLocation.startsWith('/mobile/sop/')) {
          debugPrint('  ✅ Allowing direct access to mobile SOP viewer');
          // No redirect needed - allow direct access to the SOP without login
          return null;
        }

        // If logged in, redirect to appropriate main screen based on device
        if (isLoggedIn && (isLoginRoute || isRegisterRoute)) {
          final redirectPath = isMobileDevice ? '/mobile/selection' : '/sops';
          debugPrint(
              '  🔄 Logged in user on auth route, redirecting to: $redirectPath');
          return redirectPath;
        }

        // If not logged in, redirect to appropriate login page based on device
        if (!isLoggedIn && !isLoginRoute && !isRegisterRoute) {
          final redirectPath = isMobileDevice ? '/mobile/login' : '/login';
          debugPrint('  🔄 Not logged in, redirecting to: $redirectPath');
          return redirectPath;
        }

        debugPrint('  ✅ No redirect needed');
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => _isMobileDevice(context)
              ? const MobileLoginScreen()
              : const LoginScreen(),
        ),
        GoRoute(
          path: '/mobile/login',
          builder: (context, state) => const MobileLoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),

        // Mobile selection screen route
        GoRoute(
          path: '/mobile/selection',
          builder: (context, state) => const MobileSelectionScreen(),
        ),
        // Mobile-specific routes
        GoRoute(
          path: '/mobile/sops',
          builder: (context, state) => MobileSOPsScreen(
            extraParams: state.extra as Map<String, dynamic>?,
          ),
        ),
        GoRoute(
          path: '/mobile/sop/:sopId',
          builder: (context, state) => MobileSOPViewerScreen(
            sopId: state.pathParameters['sopId'] ?? '',
            initialStepIndex:
                int.tryParse(state.uri.queryParameters['stepIndex'] ?? ''),
          ),
        ),
        GoRoute(
          path: '/mobile/editor/:sopId',
          builder: (context, state) => MobileSOPEditorScreen(
            sopId: state.pathParameters['sopId'] ?? '',
            initialStepIndex:
                int.tryParse(state.uri.queryParameters['stepIndex'] ?? ''),
          ),
        ),
        GoRoute(
          path: '/mobile/categories',
          builder: (context, state) => const MobileCategoriesScreen(),
        ),
        // Existing routes
        GoRoute(
          path: '/create-profile',
          builder: (context, state) => const CreateProfileScreen(),
        ),
        GoRoute(
          path: '/register-company',
          builder: (context, state) => const RegisterCompanyScreen(),
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const CategoriesScreen(),
        ),
        GoRoute(
          path: '/editor/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'];
            final stepIndex =
                int.tryParse(state.uri.queryParameters['stepIndex'] ?? '');
            return SOPEditorScreen(
                sopId: id ?? '', initialStepIndex: stepIndex);
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
        // MES route
        GoRoute(
          path: '/mes',
          builder: (context, state) => const MESScreen(),
        ),
        // Tablet MES routes
        GoRoute(
          path: '/timer',
          builder: (context, state) => const MESScreen(),
        ),
        GoRoute(
          path: '/item_selection',
          builder: (context, state) => const MESScreen(),
        ),
        // Process selection for MES tablet
        GoRoute(
          path: '/process_selection',
          builder: (context, state) {
            final user = state.extra as User?;
            return ProcessSelectionScreen(initialUser: user);
          },
        ),
        // MES Management route
        GoRoute(
          path: '/mes-management',
          builder: (context, state) => const MESManagementScreen(),
        ),
        // MES Reports route
        GoRoute(
          path: '/mes-reports',
          builder: (context, state) => const MESReportsScreen(),
        ),
        // Test screen for base64 image upload
        GoRoute(
          path: '/image-upload-test',
          builder: (context, state) => const ImageUploadTestScreen(),
        ),
        // User Management route (Admin only)
        GoRoute(
          path: '/user-management',
          redirect: (context, state) {
            final authService =
                Provider.of<AuthService>(context, listen: false);
            if (authService.userRole != 'admin') {
              return '/sops'; // Redirect non-admins to SOPs
            }
            return null; // Allow access for admins
          },
          builder: (context, state) => const UserManagementScreen(),
        ),
      ],
    );
  }

  // Helper method to detect if the current device is mobile or tablet
  bool _isMobileDevice(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    // Increased breakpoint to include tablets (up to 1200px is common for larger tablets)
    // - Mobile phones: < 600px
    // - Small tablets: 600px-900px
    // - Medium tablets: 900px-1024px
    // - Large tablets: 1024px-1200px
    // - Desktop/Web: > 1200px
    return mediaQuery.size.width <= 1200;
  }
}

// Helper widget to redirect mobile users to mobile-specific interface
class MobileRedirectScreen extends StatelessWidget {
  const MobileRedirectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Automatically redirect to mobile SOPs screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/mobile/sops');
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
