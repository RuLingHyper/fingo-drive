// ---------------------------------------------------------
// 1. Kütüphaneler
// ---------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fingo_drive_mobil/screens/splash_screen.dart';

// ---------------------------------------------------------
// 2. Ana Başlangıç Fonksiyonu
// ---------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const FingoDriveApp());
}

// ---------------------------------------------------------
// 3. Uygulamanın Ana İskeleti
// ---------------------------------------------------------
class FingoDriveApp extends StatelessWidget {
  const FingoDriveApp({super.key});

  // ---------------------------------------------------------
  // 4. EKRAN TASARIMI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fingo Drive',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.indigo),
          prefixIconColor: Colors.indigo,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
