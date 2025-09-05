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

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'util/setup_services.dart';
import 'utils/debug_control.dart';

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
  DebugControl.debugLog('🚀 APP: Starting application...');
  WidgetsFlutterBinding.ensureInitialized();

  // Configure URL strategy for Flutter web - ESSENTIAL for proper URL handling
  if (kIsWeb) {
    usePathUrlStrategy();
    DebugControl.debugLog('🌐 APP: Configured path URL strategy for web');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  DebugControl.debugLog('🔥 APP: Firebase initialized successfully');
  DebugControl.debugLogObject('Firebase project ID', DefaultFirebaseOptions.currentPlatform.projectId);

  // Initialize services
  DebugControl.debugLog('🔧 APP: Setting up services...');
  setupServices();
  DebugControl.debugLog('🔧 APP: Services setup complete');

  DebugControl.debugLog('🎬 APP: Running MyApp...');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    // Create single instances that won't change
    _authService = AuthService();
    _router = _createRouter(_authService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        ChangeNotifierProvider(create: (context) => SOPService()),
        ChangeNotifierProvider(create: (context) => CategoryService()),
        ChangeNotifierProvider(create: (context) => MESService()),
        ChangeNotifierProxyProvider2<AuthService, SOPService, AnalyticsService>(
          create: (context) => AnalyticsService(
            sopService: Provider.of<SOPService>(context, listen: false),
            authService: _authService,
          ),
          update: (context, authService, sopService, previous) =>
              previous ??
              AnalyticsService(
                sopService: sopService,
                authService: authService,
              ),
        ),
        ChangeNotifierProxyProvider<AuthService, UserManagementService>(
          create: (context) => UserManagementService(_authService),
          update: (context, authService, previous) =>
              previous ?? UserManagementService(authService),
        ),
      ],
      child: MaterialApp.router(
        title: "Elmo's Furniture SOP Manager",
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
      ),
    );
  }

  GoRouter _createRouter(AuthService authService) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        // Allow direct access to specific SOPs via mobile web (for QR code scanning)
        if (state.matchedLocation.startsWith('/mobile/sop/')) {
          return null;
        }
        
        // Let InitializationScreen handle all routing logic
        // This prevents router redirect loops
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const InitializationScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => _buildResponsiveLogin(context),
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

  /// Safely builds responsive login screen without causing debug issues
  Widget _buildResponsiveLogin(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use LayoutBuilder instead of MediaQuery to prevent debug service issues
        if (constraints.maxWidth <= 1200) {
          return const MobileLoginScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// Initialization screen that handles app startup properly
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  @override
  void initState() {
    super.initState();
    // Start initialization check after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialization();
    });
  }

  void _checkInitialization() async {
    // Wait a moment for services to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Wait for AuthService to initialize (with timeout)
    int attempts = 0;
    while (!authService.isInitialized && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
      if (!mounted) return;
    }
    
    if (!mounted) return;
    
    // Once initialized, redirect based on auth status
    if (authService.isLoggedIn) {
      // User is logged in, go to main app
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/sops');
        }
      });
    } else {
      // User not logged in, go to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/login');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading Elmo\'s Furniture App...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Initializing services...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
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
