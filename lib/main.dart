import 'package:flutter/material.dart';
import 'models/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF5B86E5),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Step Tracker',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
        appBarTheme: baseTheme.appBarTheme.copyWith(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: baseTheme.colorScheme.onBackground,
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: const Color(0xFF1E293B),
          displayColor: const Color(0xFF0F172A),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}