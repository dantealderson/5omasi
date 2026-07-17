import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:admin/auth_gate.dart';
import 'package:admin/firebase_options.dart';
import 'package:admin/theme/app_theme.dart';

/// App-wide theme mode. Dark is the star of the Midnight Club system; the
/// toggle lives at the bottom of the navigation rail.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'خماسي — مكتب العمليات',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          // Arabic-first, like the mobile app.
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}
