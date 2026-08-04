import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_theme.dart';

import 'features/main_shell.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
// import 'features/keanwei/wastelogs/wastelog_provider.dart';
// import 'features/keanwei/wastelogs/wastetype_provider.dart';
// import 'features/jiaqin/bins/bin_provider.dart';
// import 'features/jiaqin/logistics/logistics_provider.dart';
// import 'features/zijie/goals/goal_plan_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const WasteTrackerApp());
}

class WasteTrackerApp extends StatelessWidget {
  const WasteTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ChangeNotifierProvider(create: (_) => GoalPlanProvider()),
        // ChangeNotifierProvider(create: (_) => WasteLogProvider()),
        // ChangeNotifierProvider(create: (_) => WasteTypeProvider()),
        // ChangeNotifierProvider(create: (_) => BinProvider()),
        // ChangeNotifierProvider(create: (_) => LogisticsProvider()),
      ],
      child: MaterialApp(
        title: 'iot_app',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _wasRecovering = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Detect transition to recovery mode and clear the navigator stack
    if (auth.isRecoveringPassword && !_wasRecovering) {
      _wasRecovering = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else if (!auth.isRecoveringPassword) {
      _wasRecovering = false;
    }

    if (auth.isRecoveringPassword) {
      return const ResetPasswordScreen();
    }

    return auth.isLoggedIn ? const MainShell() : const LoginScreen();
  }
}
