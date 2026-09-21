// ---------------------------------------------------------
// 1. KÜTÜPHANELER
// ---------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:fingo_drive_mobil/services/api_service.dart';

// ---------------------------------------------------------
// 2. WIDGET TANIMI
// ---------------------------------------------------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ---------------------------------------------------------
  // 3. DEĞİŞKENLER VE KONTROLCÜLER
  // ---------------------------------------------------------
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool isLoading = false;

  bool _isObscured = true;
  bool _isConfirmObscured = true;

  // ---------------------------------------------------------
  // 4. E-POSTA KONTROLÜ (REGEX)
  // ---------------------------------------------------------
  bool _isEmailValid(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  // ---------------------------------------------------------
  // 5. DOĞRULAMA BAŞLATMA
  // ---------------------------------------------------------
  Future<void> _dogrulamaBaslat() async {
    String username = _userController.text;
    String email = _emailController.text;
    String pass = _passController.text;
    String confirmPass = _confirmPassController.text;

    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Kullanıcı adı en az 3 karakter olmalı")));
      return;
    }
    if (!_isEmailValid(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Geçerli bir E-posta girin")));
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Şifre en az 6 karakter olmalı")));
      return;
    }
    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Şifreler uyuşmuyor!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => isLoading = true);

    var result = await ApiService.sendVerificationCode(email, username);

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result['success']) {
      _kodGirmePenceresiAc();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  // ---------------------------------------------------------
  // 6. KOD GİRME PENCERESİ (Dialog)
  // ---------------------------------------------------------
  void _kodGirmePenceresiAc() {
    TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Doğrulama Kodu"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                "Lütfen ${_emailController.text} adresine gönderilen 6 haneli kodu girin."),
            const SizedBox(height: 10),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                  hintText: "123456", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sonKayit(codeController.text);
            },
            child: const Text("Doğrula ve Kayıt Ol"),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 7. SON KAYIT İŞLEMİ
  // ---------------------------------------------------------
  Future<void> _sonKayit(String code) async {
    setState(() => isLoading = true);
    var result = await ApiService.verifyAndRegister(_userController.text,
        _emailController.text, _passController.text, code);

    if (!mounted) return;

    setState(() => isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("🎉 Kayıt Başarılı!"), backgroundColor: Colors.green));
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message']), backgroundColor: Colors.red));
    }
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
            title: const Text("Kayıt Ol"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.verified_user, size: 80, color: Colors.indigo),
                const SizedBox(height: 20),
                TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                        labelText: "Kullanıcı Adı",
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: "E-Posta",
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController,
                  obscureText: _isObscured,
                  decoration: InputDecoration(
                      labelText: "Şifre",
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                          icon: Icon(_isObscured
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _isObscured = !_isObscured))),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _confirmPassController,
                  obscureText: _isConfirmObscured,
                  decoration: InputDecoration(
                      labelText: "Şifre Tekrar",
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                          icon: Icon(_isConfirmObscured
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _isConfirmObscured = !_isConfirmObscured))),
                ),
                const SizedBox(height: 25),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white),
                        onPressed: isLoading ? null : _dogrulamaBaslat,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Devam Et >",
                                style: TextStyle(fontSize: 18)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
