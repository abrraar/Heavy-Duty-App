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
bool _isFirstLoad = true;

int _lastNavIndex = 0;

int _getNavIndex(String location) {
  if (location == AppRoutes.home) return 0;
  if (location == AppRoutes.exercises) return 1;
  if (location.startsWith('/tracker')) return 2;
  if (location == AppRoutes.profile) return 3;
  return 0;
}

Page<dynamic> _directionalSlidePage({required Widget child, required GoRouterState state}) {
  final int newIndex = _getNavIndex(state.uri.path);
  final bool movingForward = newIndex > _lastNavIndex;
  
  // Update the global index tracking
  _lastNavIndex = newIndex;

  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // The animation for THIS page coming into view
      final slideIn = Tween<Offset>(
        begin: Offset(movingForward ? 1.0 : -1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      ));

      // The animation for THIS page moving out of view when another tab is selected
      // We use secondaryAnimation for the outgoing effect
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(movingForward ? -1.0 : 1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInOutCubic,
      ));

      return SlideTransition(
        position: slideIn,
        child: SlideTransition(
          position: slideOut,
          child: child,
        ),
      );
    },
  );
}

// ── Transition Helpers ────────────────────────────────

Page<dynamic> _fadeTransitionPage({required Widget child, required GoRouterState state, int duration = 600}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: duration),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Page<dynamic> _slideTransitionPage({required Widget child, required GoRouterState state, int duration = 400}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: duration),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

Page<dynamic> _sharedAxisTransitionPage({required Widget child, required GoRouterState state, int duration = 300}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: duration),
    reverseTransitionDuration: Duration(milliseconds: duration),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  refreshListenable: AuthProvider(),
  errorBuilder: (context, state) {
    final uriStr = state.uri.toString().toLowerCase();
    final source = state.uri.queryParameters['source'];

    if (uriStr.contains('email_change') || uriStr.contains('verify-secondary-email')) {
      return const ManageEmailScreen(); 
    }

    if (uriStr.contains('recovery') || uriStr.contains('reset-password')) {
      if (source == 'settings') {
        return const ChangePasswordScreen();
      }
      return const ResetPassScreen();
    }

    debugPrint("Router Catch-All Error: ${state.error}");
    return const HomeScreen();
  },
  redirect: (context, state) {
    final authProvider = AuthProvider();
    
    if (authProvider.isInitializing) {
      return null;
    }

    final isAuthenticated = authProvider.isAuthenticated;
    final isProfileComplete = authProvider.isProfileComplete;
    final location = state.uri.path;
    final fullUri = state.uri.toString().toLowerCase();

    final bool isExternalLink = fullUri.startsWith('heavyduty://');
    
    if (isExternalLink) {
      if (fullUri.contains('email_change') || fullUri.contains('verify-secondary-email')) {
        final message = state.uri.queryParameters['message'];
        final email = state.uri.queryParameters['email'];
        
        String path = '${AppRoutes.manageEmail}?verified=true';
        if (message != null) path += '&message=${Uri.encodeComponent(message)}';
        if (email != null) path += '&email=${Uri.encodeComponent(email)}';
        
        return path;
      }
      
      if (fullUri.contains('recovery') || fullUri.contains('reset-password')) {
        final source = state.uri.queryParameters['source'];
        if (source == 'settings') return AppRoutes.changePassword;
        return AppRoutes.resetPass;
      }
    }

    if (authProvider.isPasswordRecoveryMode) {
      final bool isAtResetScreen = location == AppRoutes.resetPass || location == AppRoutes.changePassword;
      final bool isAtEssential = [AppRoutes.splash, AppRoutes.root, AppRoutes.login].contains(location);
      
      if (!isAtResetScreen && !isAtEssential) {
        return AppRoutes.resetPass;
      }
    }

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
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: AppRoutes.splash,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _fadeTransitionPage(child: const FadeSplashScreen(), state: state, duration: 800),
    ),
    GoRoute(
      path: AppRoutes.login,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
        opaque: false, // Essential for splash zoom handover
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.signin,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _fadeTransitionPage(child: const SignInScreen(), state: state),
    ),
    GoRoute(
      path: AppRoutes.forgotPass,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _fadeTransitionPage(child: const ForgotPassScreen(), state: state),
    ),
    GoRoute(
      path: AppRoutes.otp,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _fadeTransitionPage(child: const OtpScreen(), state: state),
    ),
    GoRoute(
      path: AppRoutes.resetPass,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _fadeTransitionPage(child: const ResetPassScreen(), state: state),
    ),
    GoRoute(
      path: AppRoutes.createProfilePersonal,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _fadeTransitionPage(child: const CreateAccPersoScreen(), state: state),
    ),
    GoRoute(
      path: AppRoutes.alarmRinging,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final extras = state.extra as Map<String, dynamic>?;
        return _fadeTransitionPage(
          child: AlarmRingingScreen(
            alarmId: extras?['id'] as int? ?? 0,
            label: extras?['label'] as String? ?? "Recovery Alarm",
          ),
          state: state,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.shareCycle,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return _fadeTransitionPage(child: ImportCycleScreen(shareId: shareId, senderName: from), state: state);
      },
    ),
    GoRoute(
      path: AppRoutes.shareMeal,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return _fadeTransitionPage(child: ImportMealScreen(shareId: shareId, senderName: from), state: state);
      },
    ),
    GoRoute(
      path: AppRoutes.shareSupplement,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return _fadeTransitionPage(child: ImportSupplementScreen(shareId: shareId, senderName: from), state: state);
      },
    ),
    GoRoute(
      path: AppRoutes.shareStack,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return _fadeTransitionPage(child: ImportStackScreen(shareId: shareId, senderName: from), state: state);
      },
    ),
    GoRoute(
      path: AppRoutes.shareExercise,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final shareId = state.uri.queryParameters['id'] ?? "";
        final from = state.uri.queryParameters['from'] ?? "A User";
        return _fadeTransitionPage(child: ImportExerciseScreen(shareId: shareId, senderName: from), state: state);
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
          pageBuilder: (context, state) => _directionalSlidePage(child: const HomeScreen(), state: state),
        ),
        GoRoute(
          path: AppRoutes.exercises,
          pageBuilder: (context, state) => _directionalSlidePage(child: const ExerciseScreen(), state: state),
        ),
        GoRoute(
          path: AppRoutes.tracker,
          pageBuilder: (context, state) => _directionalSlidePage(child: const TrackerScreen(), state: state),
          routes: [
            GoRoute(
              path: 'cycle',
              pageBuilder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return _slideTransitionPage(child: CycleTrackingScreen(initialTabIndex: tab), state: state);
              },
            ),
            GoRoute(
              path: 'calorie',
              pageBuilder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return _slideTransitionPage(child: CalorieScreen(initialTabIndex: tab), state: state);
              },
            ),
            GoRoute(
              path: 'supplement',
              pageBuilder: (context, state) {
                final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
                return _slideTransitionPage(child: SupplementScreen(initialTabIndex: tab), state: state);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) => _directionalSlidePage(child: const ProfileScreen(), state: state),
          routes: [
            GoRoute(
              path: 'edit',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) => _slideTransitionPage(child: const EditProfileScreen(), state: state),
            ),
            GoRoute(
              path: 'change-username',
              parentNavigatorKey: _rootNavigatorKey,
              pageBuilder: (context, state) => _slideTransitionPage(child: const ChangeUsernameScreen(), state: state),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.settings,
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) => _slideTransitionPage(child: const SettingsScreen(), state: state),
      routes: [
        GoRoute(
          path: 'notifications',
          pageBuilder: (context, state) => _slideTransitionPage(child: const NotificationSettingsScreen(), state: state),
        ),
        GoRoute(
          path: 'cycle',
          pageBuilder: (context, state) => _slideTransitionPage(child: const CycleTrackingSettingsScreen(), state: state),
        ),
        GoRoute(
          path: 'calorie',
          pageBuilder: (context, state) => _slideTransitionPage(child: const CalorieSettingsScreen(), state: state),
          routes: [
             GoRoute(
                path: 'import',
                pageBuilder: (context, state) => _slideTransitionPage(
                  child: ImportMealScreen(
                    shareId: state.uri.queryParameters['id'] ?? "",
                    senderName: state.uri.queryParameters['from'] ?? "A User",
                  ),
                  state: state,
                ),
             )
          ]
        ),
        GoRoute(
          path: 'hydration',
          pageBuilder: (context, state) => _slideTransitionPage(child: const HydrationSettingsScreen(), state: state),
        ),
        GoRoute(
          path: 'supplement',
          pageBuilder: (context, state) => _slideTransitionPage(child: const SupplementSettingsScreen(), state: state),
        ),
        GoRoute(
          path: 'sleep',
          pageBuilder: (context, state) => _slideTransitionPage(child: const SleepSettingsScreen(), state: state),
        ),
        GoRoute(
          path: 'body-comp',
          pageBuilder: (context, state) => _slideTransitionPage(child: const BodyCompConfigScreen(), state: state),
        ),
        GoRoute(
          path: 'manage-email',
          pageBuilder: (context, state) => _slideTransitionPage(child: const ManageEmailScreen(), state: state),
        ),
        GoRoute(
          path: 'change-password',
          pageBuilder: (context, state) => _slideTransitionPage(child: const ChangePasswordScreen(), state: state),
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
