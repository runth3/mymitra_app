import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Default color scheme pake merah kalem
  static final _defaultColor = ColorScheme.fromSeed(seedColor: Colors.red[300]!);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightColorScheme = lightDynamic ?? _defaultColor;
        ColorScheme darkColorScheme = darkDynamic ?? _defaultColor;

        return MaterialApp(
          title: 'Mitra Aplikasi',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          themeMode: ThemeMode.system,
          home: const SplashScreen(),
        );
      },
    );
  }
}