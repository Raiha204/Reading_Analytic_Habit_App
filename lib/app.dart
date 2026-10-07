import 'package:flutter/material.dart';

import 'package:flutter_demo_app/domain/models/reading_models.dart';
import 'package:flutter_demo_app/features/auth/presentation/pages/auth_page.dart';
import 'package:flutter_demo_app/features/home/presentation/pages/reading_home_page.dart';

class ReadingHabitAnalyticsApp extends StatelessWidget {
  const ReadingHabitAnalyticsApp({
    super.key,
    this.requireAuthentication = true,
  });

  final bool requireAuthentication;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Readwise',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: ReadingColors.green,
          brightness: Brightness.light,
          primary: ReadingColors.forest,
          secondary: ReadingColors.green,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: requireAuthentication ? const AuthGate() : const ReadingHomePage(),
    );
  }
}
