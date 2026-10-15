// ---------------------------------------------------------
// 1. KÜTÜPHANELER
// ---------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:fingo_drive_mobil/services/api_service.dart';
import 'package:fingo_drive_mobil/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------
// 2. WIDGET TANIMI
// ---------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  final String currentUsername;

  const SettingsScreen({super.key, required this.currentUsername});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ---------------------------------------------------------
  // 3. ŞİFRE DEĞİŞTİRME FONKSİYONU
  // ---------------------------------------------------------
  Future<void> _sifreDegistirDialog() async {
    TextEditingController passController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Şifre Değiştir"),
        content: TextField(
          controller: passController,
          obscureText: true,
          decoration:
              const InputDecoration(hintText: "Yeni Şifre (En az 6 haneli)"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (passController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Şifre en az 6 karakter olmalı")));
                return;
              }

              Navigator.pop(ctx);

              var res = await ApiService.updateSingleProfile(
                  widget.currentUsername, "password", passController.text);

              if (!mounted) return;

              if (res['success']) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("✅ Şifre başarıyla değiştirildi!"),
                    backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Hata: ${res['message']}"),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Güncelle"),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 4. KULLANICI ADI DEĞİŞTİRME FONKSİYONU
  // ---------------------------------------------------------
  Future<void> _kullaniciAdiDegistirDialog() async {
    TextEditingController userController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kullanıcı Adı Değiştir"),
        content: TextField(
          controller: userController,
          decoration: const InputDecoration(hintText: "Yeni Kullanıcı Adı"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (userController.text.isEmpty) return;
              Navigator.pop(ctx);

              var res = await ApiService.updateSingleProfile(
                  widget.currentUsername, "username", userController.text);

              if (!mounted) return;

              if (res['success']) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text("✅ Kullanıcı adı güncellendi! Çıkış yapılıyor..."),
                    backgroundColor: Colors.green));
                await Future.delayed(const Duration(seconds: 2));
                if (!mounted) return;
                _cikisYapVeLoginGit();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Hata: ${res['message']}"),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Güncelle"),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 5. E-POSTA DEĞİŞTİRME FONKSİYONU
  // ---------------------------------------------------------
  Future<void> _emailDegistirDialog() async {
    TextEditingController emailController = TextEditingController();
    TextEditingController codeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("E-Posta Değiştir"),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "Yeni E-Posta Adresi"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) return;
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Doğrulama kodu gönderiliyor...")));

              var res = await ApiService.requestEmailChange(
                  widget.currentUsername, emailController.text);

              if (!mounted) return;

              if (res['success']) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx2) => AlertDialog(
                    title: const Text("Doğrulama Kodu"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Kod gönderildi: ${emailController.text}"),
                        const SizedBox(height: 10),
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: "Kodu girin"),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2),
                        child: const Text("İptal"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx2);

                          var verifyRes = await ApiService.confirmEmailChange(
                              widget.currentUsername,
                              emailController.text,
                              codeController.text);

                          if (!mounted) return;

                          if (verifyRes['success']) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "✅ E-Posta başarıyla değiştirildi!"),
                                    backgroundColor: Colors.green));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text("Hata: ${verifyRes['message']}"),
                                backgroundColor: Colors.red));
                          }
                        },
                        child: const Text("Onayla"),
                      )
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Hata: ${res['message']}"),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Kod Gönder"),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 6. HESAP SİLME FONKSİYONU
  // ---------------------------------------------------------
  Future<void> _hesapSilmeSureci() async {
    bool? onayla = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("HESABI SİL"),
        content: const Text(
            "Bu işlem geri alınamaz! Tüm dosyaların silinecek.\nDevam etmek istiyor musun?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Evet, Kod Gönder"),
          )
        ],
      ),
    );

    if (onayla == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Silme kodu e-postana gönderiliyor...")));

      var res = await ApiService.requestAccountDeletion(widget.currentUsername);

      if (!mounted) return;

      if (res['success']) {
        TextEditingController codeCtrl = TextEditingController();
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c2) => AlertDialog(
            title: const Text("Son Onay"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("E-postana gelen kodu gir:"),
                const SizedBox(height: 10),
                TextField(
                    controller: codeCtrl, keyboardType: TextInputType.number),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c2),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(c2);
                  var delRes = await ApiService.confirmAccountDeletion(
                      widget.currentUsername, codeCtrl.text);

                  if (!mounted) return;

                  if (delRes) {
                    _cikisYapVeLoginGit();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Hatalı kod! İşlem iptal edildi."),
                        backgroundColor: Colors.red));
                  }
                },
                child: const Text("HESABI KALICI OLARAK SİL"),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Hata: ${res['message']}"),
            backgroundColor: Colors.red));
      }
    }
  }

  // ---------------------------------------------------------
  // 7. YARDIMCI: ÇIKIŞ YAPMA
  // ---------------------------------------------------------
  Future<void> _cikisYapVeLoginGit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (c) => const LoginScreen()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------
  // 8. EKRAN TASARIMI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Hesap İşlemleri",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.password, color: Colors.blue),
            title: const Text("Şifre Değiştir"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _sifreDegistirDialog,
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.orange),
            title: const Text("Kullanıcı Adı Değiştir"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _kullaniciAdiDegistirDialog,
          ),
          ListTile(
            leading: const Icon(Icons.email, color: Colors.purple),
            title: const Text("E-Posta Değiştir"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _emailDegistirDialog,
          ),
          const SizedBox(height: 30),
          const Text("Tehlikeli Bölge",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Hesabı Sil",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _hesapSilmeSureci,
          ),
        ],
      ),
    );
  }
}
