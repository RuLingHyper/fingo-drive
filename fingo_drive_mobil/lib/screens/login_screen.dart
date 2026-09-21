// ignore_for_file: use_build_context_synchronously
// ---------------------------------------------------------
// 1. KÜTÜPHANELER
// ---------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fingo_drive_mobil/screens/home_screen.dart';
import 'package:fingo_drive_mobil/screens/register_screen.dart';
import 'package:fingo_drive_mobil/services/api_service.dart';

// ---------------------------------------------------------
// 2. EKRAN TANIMI (STATEFUL WIDGET)
// ---------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ---------------------------------------------------------
  // 3. DEĞİŞKENLER VE KONTROLCÜLER
  // ---------------------------------------------------------
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLoading = false;
  bool _isObscured = true;

  // ---------------------------------------------------------
  // 4. IP AYAR PENCERESİ
  // ---------------------------------------------------------
  void _ayarPenceresiAc() async {
    String currentUrl = await ApiService.getBaseUrl();
    String cleanIp =
        currentUrl.replaceAll("http://", "").replaceAll(":8000", "");

    TextEditingController ipController = TextEditingController(text: cleanIp);

    if (!mounted) return;

    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text("Sunucu IP"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Bilgisayarın IPv4 adresini girin:"),
                  const SizedBox(height: 10),
                  TextField(
                      controller: ipController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          hintText: "192.168.1.128",
                          border: OutlineInputBorder())),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("İptal")),
                ElevatedButton(
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(context);

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                          'server_ip', "http://${ipController.text}:8000");

                      if (mounted) {
                        navigator.pop();
                        messenger.showSnackBar(const SnackBar(
                            content: Text("IP Adresi Güncellendi!")));
                      }
                    },
                    child: const Text("Kaydet"))
              ],
            ));
  }

  // ---------------------------------------------------------
  // 5. GİRİŞ YAPMA FONKSİYONU
  // ---------------------------------------------------------
  Future<void> _girisYap() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen bilgileri eksiksiz girin.")));
      return;
    }

    setState(() => isLoading = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    var result =
        await ApiService.login(_emailController.text, _passwordController.text);

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result['success']) {
      navigator.pushReplacement(MaterialPageRoute(
          builder: (context) => HomeScreen(
              token: result['data']['token'],
              username: result['data']['username'])));
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text("⛔ ${result['message']}"),
          backgroundColor: Colors.red));
    }
  }

  // ---------------------------------------------------------
  // 6. ŞİFREMİ UNUTTUM - ADIM 1 (E-posta İste)
  // ---------------------------------------------------------
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Şifremi Unuttum"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: "E-posta Adresiniz"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.requestPasswordReset(
                    emailController.text.trim());
                Navigator.pop(context);

                if (mounted) {
                  _showResetConfirmDialog(emailController.text.trim(),
                      codeController, passwordController);
                }
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text("Hata: $e")));
              }
            },
            child: const Text("Kod Gönder"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 7. ŞİFREMİ UNUTTUM - ADIM 2 (Kod ve Yeni Şifre)
  // ---------------------------------------------------------
  void _showResetConfirmDialog(String email, TextEditingController codeCtrl,
      TextEditingController passCtrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Şifreyi Sıfırla"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Lütfen $email adresine gelen kodu girin."),
            const SizedBox(height: 10),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: "Gelen Kod"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "Yeni Şifre"),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.confirmPasswordReset(
                    email, codeCtrl.text.trim(), passCtrl.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Şifreniz başarıyla değişti! Giriş yapabilirsiniz.")));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text("Hata: $e")));
              }
            },
            child: const Text("Şifreyi Değiştir"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 8. EKRAN TASARIMI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
            title: const Text("Fingo Drive",
                style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: "Sunucu Ayarları",
                  onPressed: _ayarPenceresiAc)
            ]),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (c, o, s) => const Icon(Icons.cloud_circle,
                        size: 100, color: Colors.indigo)),
                const SizedBox(height: 30),
                TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: "E-Posta",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscured,
                  decoration: InputDecoration(
                      labelText: "Şifre",
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscured
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _isObscured = !_isObscured),
                      )),
                ),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text("Şifremi Unuttum?",
                            style: TextStyle(color: Colors.indigo)))),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white),
                        onPressed: isLoading ? null : _girisYap,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Giriş Yap",
                                style: TextStyle(fontSize: 18)))),
                const SizedBox(height: 20),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const RegisterScreen())),
                    child: const Text("Hesabın yok mu? Kayıt Ol",
                        style: TextStyle(color: Colors.indigo))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
