// ---------------------------------------------------------
// 1. KÜTÜPHANELER
// ---------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fingo_drive_mobil/screens/home_screen.dart';
import 'package:fingo_drive_mobil/screens/login_screen.dart';

// ---------------------------------------------------------
// 2. STATEFUL WIDGET YAPISI
// ---------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  // ---------------------------------------------------------
  // 3. BAŞLANGIÇ TETİĞİ (initState)
  // ---------------------------------------------------------
  void initState() {
    super.initState();
    _baslangicKontrolleri();
  }

  // ---------------------------------------------------------
  // 4. ANA KONTROL FONKSİYONU
  // ---------------------------------------------------------
  Future<void> _baslangicKontrolleri() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final String? username = prefs.getString('username');

      if (!mounted) return;

      if (token != null && username != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(token: token, username: username),
          ),
        );
      } else {
        _girisEkraninaGit();
      }
    } catch (e) {
      debugPrint("Splash Hatası: $e");
      if (mounted) _girisEkraninaGit();
    }
  }

  void _girisEkraninaGit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // ---------------------------------------------------------
  // 5. EKRAN TASARIMI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.cloud_upload,
                  size: 100,
                  color: Colors.white,
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Fingo Drive",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
