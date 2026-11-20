import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KallosApp());
}

class KallosApp extends StatelessWidget {
  const KallosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kallos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      home: const SplashScreen(),
    );
  }
}
