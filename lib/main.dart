import 'package:elmos_furniture_app/data/services/auth_service.dart';
import 'package:elmos_furniture_app/data/services/sop_service.dart';
import 'package:elmos_furniture_app/data/services/analytics_service.dart';
import 'package:elmos_furniture_app/data/services/category_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'utils/deep_link_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/populate_firebase.dart';
import 'util/setup_services.dart';

// Screens
// import 'presentation/screens/home_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/create_profile_screen.dart';
import 'presentation/screens/auth/register_company_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/categories/categories_screen.dart';
import 'presentation/screens/sop_editor/sop_editor_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/analytics/analytics_screen.dart';
import 'presentation/screens/sops/sops_screen.dart';
import 'presentation/screens/mobile/mobile_redirect_screen.dart';
import 'presentation/screens/mobile/mobile_sop_viewer_screen.dart';
import 'presentation/screens/mobile/mobile_categories_screen.dart';
import 'presentation/screens/mobile/mobile_sops_screen.dart';
import 'presentation/screens/mobile/mobile_login_screen.dart';
import 'presentation/screens/mobile/mobile_sop_editor_screen.dart';
import 'presentation/screens/image_upload_test_screen.dart';
// import 'presentation/screens/recipe_screen.dart';

// Services and Models
import 'core/theme/app_theme.dart';
// import 'data/services/database_service.dart';
// import 'data/services/storage_service.dart';
// import 'utils/app_router.dart';
// import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('Starting Firebase initialization...');

  // Initialize services
  setupServices();

  runApp(const MyApp());
  debugPrint('✅ Firebase initialized successfully');
  debugPrint(
      'Firebase project ID: ${DefaultFirebaseOptions.currentPlatform.projectId}');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => SOPService()),
        ChangeNotifierProvider(create: (context) => CategoryService()),
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
      child: Consumer<AuthService>(
        builder: (context, authService, child) {
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
    return GoRouter(
      initialLocation: '/dashboard',
      redirect: (context, state) {
        final bool isLoggedIn = authService.isLoggedIn;
        final bool isLoginRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/mobile/login';
        final bool isRegisterRoute = state.matchedLocation == '/register';

        // Check if the user is on a mobile device
        final bool isMobileDevice = _isMobileDevice(context);

        // Special case: Allow direct access to specific SOPs via mobile web (for QR code scanning)
        // This bypasses authentication for mobile SOP viewer when accessed directly
        if (state.matchedLocation.startsWith('/mobile/sop/')) {
          // No redirect needed - allow direct access to the SOP without login
          return null;
        }

        // If logged in, redirect to appropriate dashboard based on device
        if (isLoggedIn && (isLoginRoute || isRegisterRoute)) {
          return isMobileDevice ? '/mobile/sops' : '/dashboard';
        }

        // If not logged in, redirect to appropriate login page based on device
        if (!isLoggedIn && !isLoginRoute && !isRegisterRoute) {
          return isMobileDevice ? '/mobile/login' : '/login';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) {
            if (authService.isLoggedIn) {
              return _isMobileDevice(context) ? '/mobile/sops' : '/dashboard';
            }
            return _isMobileDevice(context) ? '/mobile/login' : '/login';
          },
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
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => _isMobileDevice(context)
              ? const MobileRedirectScreen()
              : const DashboardScreen(),
        ),
        // Mobile-specific routes
        GoRoute(
          path: '/mobile/sops',
          builder: (context, state) => const MobileSOPsScreen(),
        ),
        GoRoute(
          path: '/mobile/sop/:sopId',
          builder: (context, state) => MobileSOPViewerScreen(
            sopId: state.pathParameters['sopId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/mobile/editor/:sopId',
          builder: (context, state) => MobileSOPEditorScreen(
            sopId: state.pathParameters['sopId'] ?? '',
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
        // Test screen for base64 image upload
        GoRoute(
          path: '/image-upload-test',
          builder: (context, state) => const ImageUploadTestScreen(),
        ),
      ],
    );
  }

  // Helper method to detect if the current device is mobile or tablet
  bool _isMobileDevice(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    // Increased breakpoint to include tablets (up to 1024px is common for tablets)
    // - Mobile phones: < 600px
    // - Small tablets: 600px-900px
    // - Large tablets: 900px-1024px
    // - Desktop/Web: > 1024px
    return mediaQuery.size.width <= 1024;
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
