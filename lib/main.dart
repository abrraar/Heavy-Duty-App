// main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/constants/app_constants.dart';
import 'package:heavy_duty/core/theme/app_picker_theme.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:heavy_duty/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:heavy_duty/features/tracker/sleep/provider/sleep_alarm_provider.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/navigation/app_router.dart';
import 'package:heavy_duty/core/services/notification_service.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alarm/alarm.dart';

import 'features/tracker/body_composition/provider/body_comp_provider.dart';
import 'features/affirmation/provider/affirmation_provider.dart';
import 'core/providers/ui_provider.dart';
import 'features/tracker/supplement/provider/supplement_provider.dart';
import 'core/providers/update_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure this is first

  await Alarm.init();
  await NotificationService().init();
  ConnectivityService().init();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // LOCK TO PORTRAIT MODE
  // Ensures the app stays in portrait even if auto-rotate is enabled
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupplementProvider()),
        ChangeNotifierProvider(create: (_) => HydrationProvider()),
        ChangeNotifierProvider(create: (_) => SleepProvider()),
        ChangeNotifierProvider(create: (_) => SleepAlarmProvider()),
        ChangeNotifierProvider(create: (_) => CalorieProvider()),
        ChangeNotifierProvider(create: (_) => BodyCompProvider()),
        ChangeNotifierProvider(create: (_) => CycleProvider()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => UiProvider()),
        ChangeNotifierProvider(create: (_) => AffirmationProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: const AuthWrapper(child: MyApp()),
    ),
  );
}

// Added an AuthWrapper to listen to auth changes and trigger DB initialization
class AuthWrapper extends StatefulWidget {
  final Widget child;
  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    
    // Initialize Alarms
    context.read<SleepAlarmProvider>().init();

    // Check for Updates
    context.read<UpdateProvider>().init();
    
    // Listen to Auth changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      final suppProvider = Provider.of<SupplementProvider>(context, listen: false);
      final hydrationProvider = Provider.of<HydrationProvider>(context, listen: false);
      final sleepProvider = Provider.of<SleepProvider>(context, listen: false);
      final sleepAlarmProvider = Provider.of<SleepAlarmProvider>(context, listen: false);
      final calorieProvider = Provider.of<CalorieProvider>(context, listen: false);
      final bodyCompProvider = Provider.of<BodyCompProvider>(context, listen: false);
      final cycleProvider = Provider.of<CycleProvider>(context, listen: false);
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final uiProvider = Provider.of<UiProvider>(context, listen: false);
      final affirmationProvider = Provider.of<AffirmationProvider>(context, listen: false);

      if (user != null) {
        suppProvider.initializeForUser(user.id);
        hydrationProvider.initializeForUser(user.id);
        sleepProvider.initializeForUser(user.id);
        sleepAlarmProvider.initializeForUser(user.id);
        calorieProvider.initializeForUser(user.id);
        bodyCompProvider.initializeForUser(user.id);
        cycleProvider.initializeForUser(user.id);
        exerciseProvider.initializeForUser(user.id);
        uiProvider.initializeForUser(user.id);
        affirmationProvider.initializeForUser(user.id);
      } else {
        suppProvider.clearUserData();
        hydrationProvider.clearUserData();
        sleepProvider.clearUserData();
        calorieProvider.clearUserData();
        bodyCompProvider.clearUserData();
        cycleProvider.clearUserData();
        exerciseProvider.clearUserData();
        uiProvider.clearUserData();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp.router(
        title: 'Heavy Duty',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: AppPickerTheme.themeData,
      ),
    );
  }
}
