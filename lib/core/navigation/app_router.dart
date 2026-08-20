import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/features/auth/screen/otp_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';

import 'package:heavy_duty/features/auth/screen/signin_screen.dart';
import 'package:heavy_duty/features/auth/screen/login_screen.dart';
import 'package:heavy_duty/features/auth/screen/forgetpass_screen.dart';
import 'package:heavy_duty/features/auth/screen/resetpass_screen.dart';
import 'package:heavy_duty/features/exercise/exercise_screen.dart';
import 'package:heavy_duty/features/home/home_screen.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:heavy_duty/features/profile/create_acc_perso_screen.dart';
import 'package:heavy_duty/features/profile/profile.dart';
import 'package:heavy_duty/features/profile/edit_profile_screen.dart';
import 'package:heavy_duty/features/profile/change_username_screen.dart';
import 'package:heavy_duty/features/profile/change_password_screen.dart';
import 'package:heavy_duty/features/profile/manage_email_screen.dart';
import 'package:heavy_duty/features/settings/settings_screen.dart';
import 'package:heavy_duty/features/settings/notification_screen.dart';
import 'package:heavy_duty/features/settings/cycle_tracking_settings_screen.dart';
import 'package:heavy_duty/features/settings/calorie_settings_screen.dart';
import 'package:heavy_duty/features/settings/hydration_settings_screen.dart';
import 'package:heavy_duty/features/settings/supplement_settings_screen.dart';
import 'package:heavy_duty/features/settings/sleep_settings_screen.dart';
import 'package:heavy_duty/features/settings/body_comp_settings_screen.dart';
import 'package:heavy_duty/features/splash/splash_screen.dart';
import 'package:heavy_duty/features/tracker/tracker_screen.dart';
import 'package:heavy_duty/features/tracker/calorie/calorie_screen.dart';
import 'package:heavy_duty/features/tracker/supplement/supplement_screen.dart';
import 'package:heavy_duty/features/tracker/sleep/screens/alarm_ringing_screen.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/cycle_tracking_screen.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/import_cycle_screen.dart';
import 'package:heavy_duty/features/tracker/calorie/import_meal_screen.dart';
import 'package:heavy_duty/features/exercise/import_exercise_screen.dart';
import 'package:heavy_duty/features/tracker/supplement/import_supplement_screen.dart';
import 'package:heavy_duty/features/tracker/supplement/import_stack_screen.dart';

import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

bool _hasLoadedUserData = false;

// Track if this is the first time the router is processing a request (to handle cold starts)
bool _isFirstLoad = true;

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash, // Start at Splash
  refreshListenable: AuthProvider(),
  errorBuilder: (context, state) {
    final uriStr = state.uri.toString().toLowerCase();
    final source = state.uri.queryParameters['source'];

    if (uriStr.contains('email_change') || uriStr.contains('verify-secondary-email')) {
      return const ManageEmailScreen(); 
    }

    if (uriStr.contains('recovery') || uriStr.contains('reset-password')) {
      // FIX: Respect the source parameter even in the error fallback
      if (source == 'settings') {
        debugPrint("Router Error Fallback: Source is 'settings'. Showing ChangePasswordScreen.");
        return const ChangePasswordScreen();
      }
      debugPrint("Router Error Fallback: Source is 'auth' or missing. Showing ResetPassScreen.");
      return const ResetPassScreen();
    }

    debugPrint("Router Catch-All Error: ${state.error}");
    return const HomeScreen();
  },
  redirect: (context, state) {
    final authProvider = AuthProvider();
    
    // 0. INITIALIZATION LOCK: Block all navigation decisions until the 
    // AuthProvider has finished its security checks (like cleaning up recovery sessions).
    if (authProvider.isInitializing) {
      debugPrint("Router: Auth initialization in progress. Holding navigation.");
      return null; // Stay on Splash/Current screen until ready
    }

    final isAuthenticated = authProvider.isAuthenticated;
    final isProfileComplete = authProvider.isProfileComplete;
    final location = state.uri.path;
    final fullUri = state.uri.toString().toLowerCase();

    // 0. HIGH-PRIORITY DEEP LINK MAPPING
    // Only intercept if we are coming from an EXTERNAL deep link (scheme starts with heavyduty://)
    final bool isExternalLink = fullUri.startsWith('heavyduty://');
    
    if (isExternalLink) {
      if (fullUri.contains('email_change') || fullUri.contains('verify-secondary-email')) {
        debugPrint("Router Match: Mapping external email deep link to /settings/manage-email");
        final message = state.uri.queryParameters['message'];
        final email = state.uri.queryParameters['email']; // Extract email if present
        
        String path = '${AppRoutes.manageEmail}?verified=true';
        if (message != null) path += '&message=${Uri.encodeComponent(message)}';
        if (email != null) path += '&email=${Uri.encodeComponent(email)}';
        
        return path;
      }
      
      if (fullUri.contains('recovery') || fullUri.contains('reset-password')) {
        debugPrint("Router Match: RECOVERY LINK DETECTED. Analyzing source...");
        
        final source = state.uri.queryParameters['source'];
        if (source == 'settings') {
          debugPrint("Router Match: Source is 'settings'. Mapping to internal changePassword.");
          return AppRoutes.changePassword;
        }

        debugPrint("Router Match: Source is 'auth' or missing. Mapping to ResetPassScreen solo.");
        return AppRoutes.resetPass;
      }
    }

    // 1. SECURITY LOCKDOWN: Password Recovery Guard
    if (authProvider.isPasswordRecoveryMode) {
      final bool isAtResetScreen = location == AppRoutes.resetPass || location == AppRoutes.changePassword;
      final bool isAtEssential = [AppRoutes.splash, AppRoutes.root, AppRoutes.login].contains(location);
      
      if (!isAtResetScreen && !isAtEssential) {
        debugPrint("Router SECURITY: Lockdown active. Bouncing $location -> Reset Screen.");
        return AppRoutes.resetPass;
      }
    }

    // 1. ALLOWLIST: Exempt specific landing paths from standard redirects
    final List<String> alwaysAllowed = [
      AppRoutes.changePassword,
      AppRoutes.manageEmail,
      AppRoutes.authCallback,
    ];

    if (alwaysAllowed.any((p) => location.startsWith(p))) {
      return null;
    }

    if (_isFirstLoad) _isFirstLoad = false;

    final isAuthRoute = [
      AppRoutes.login,
      AppRoutes.signin,
      AppRoutes.forgotPass,
      AppRoutes.otp,
      AppRoutes.resetPass,
      AppRoutes.splash,
    ].contains(location);

    // Standard Auth Logic
    if (!isAuthenticated) {
      if (!isAuthRoute && location != AppRoutes.root) {
        return '${AppRoutes.login}?from=${Uri.encodeComponent(location)}';
      }
      if (location == AppRoutes.root) return AppRoutes.login;
      return null;
    }

    if (!isProfileComplete) {
      if (location == AppRoutes.createProfilePersonal || location == AppRoutes.otp) return null;
      return AppRoutes.createProfilePersonal;
    }

    if (isAuthenticated && isProfileComplete) {
      if (!_hasLoadedUserData) {
        _hasLoadedUserData = true;
        context.read<SupplementProvider>().loadFromDatabase();
      }

      if (isAuthRoute || location == AppRoutes.root || location == AppRoutes.createProfilePersonal) {
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) return from;
        return AppRoutes.home;
      }
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.root,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SizedBox.shrink(), // Root is just a redirector
    ),
    GoRoute(
      path: AppRoutes.splash,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FadeSplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.signin,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPass,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ForgotPassScreen(),
    ),
    GoRoute(
      path: AppRoutes.otp,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OtpScreen(),
    ),
    GoRoute(
      path: AppRoutes.createProfilePersonal,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CreateAccPersoScreen(),
    ),
    GoRoute(
      path: AppRoutes.alarmRinging,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return AlarmRingingScreen(
          alarmId: extras?['id'] as int? ?? 0,
          label: extras?['label'] as String? ?? "Recovery Alarm",
        );
      },
    ),
    GoRoute(
      path: AppRoutes.shareCycle,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return ImportCycleScreen(shareId: shareId, senderName: from);
      },
    ),
    GoRoute(
      path: AppRoutes.shareMeal,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return ImportMealScreen(shareId: shareId, senderName: from);
      },
    ),
    GoRoute(
      path: AppRoutes.shareSupplement,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return ImportSupplementScreen(shareId: shareId, senderName: from);
      },
    ),
    GoRoute(
      path: AppRoutes.shareStack,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return ImportStackScreen(shareId: shareId, senderName: from);
      },
    ),
    GoRoute(
      path: AppRoutes.shareExercise,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return ImportExerciseScreen(shareId: shareId, senderName: from);
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        int index = 0;
        final location = state.uri.path;

        if (location == AppRoutes.home) {
          index = 0;
        } else if (location == AppRoutes.exercises) {
          index = 1;
        } else if (location.startsWith('/tracker')) {
          index = 2;
        } else if (location == AppRoutes.profile) {
          index = 3;
        }

        return MainWrapper(currentIndex: index, child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.exercises,
          builder: (context, state) => const ExerciseScreen(),
        ),
        GoRoute(
          path: AppRoutes.tracker,
          builder: (context, state) => const TrackerScreen(),
          routes: [
            GoRoute(
              path: 'cycle',
              builder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return CycleTrackingScreen(initialTabIndex: tab);
              },
            ),
            GoRoute(
              path: 'calorie',
              builder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return CalorieScreen(initialTabIndex: tab);
              },
            ),
            GoRoute(
              path: 'supplement',
              builder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return SupplementScreen(initialTabIndex: tab);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const EditProfileScreen(),
            ),
            GoRoute(
              path: 'change-username',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const ChangeUsernameScreen(),
            ),
          ],
        ),
      ],
    ),
    // Move Settings outside the ShellRoute to avoid redundancy issues and clarify hierarchy
    GoRoute(
      path: AppRoutes.settings,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'notifications',
          builder: (context, state) => const NotificationSettingsScreen(),
        ),
        GoRoute(
          path: 'cycle',
          builder: (context, state) => const CycleTrackingSettingsScreen(),
        ),
        GoRoute(
          path: 'calorie',
          builder: (context, state) => const CalorieSettingsScreen(),
          routes: [
             GoRoute(
                path: 'import',
                builder: (context, state) => ImportMealScreen(
                  shareId: state.uri.queryParameters['id'] ?? "",
                  senderName: state.uri.queryParameters['from'] ?? "A User",
                ),
             )
          ]
        ),
        GoRoute(
          path: 'hydration',
          builder: (context, state) => const HydrationSettingsScreen(),
        ),
        GoRoute(
          path: 'supplement',
          builder: (context, state) => const SupplementSettingsScreen(),
        ),
        GoRoute(
          path: 'sleep',
          builder: (context, state) => const SleepSettingsScreen(),
        ),
        GoRoute(
          path: 'body-comp',
          builder: (context, state) => const BodyCompConfigScreen(),
        ),
        GoRoute(
          path: 'manage-email',
          builder: (context, state) => const ManageEmailScreen(),
        ),
        GoRoute(
          path: 'change-password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),
      ],
    ),
  ],
);

class AuthProviderListenable extends ChangeNotifier {
  AuthProviderListenable() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}
