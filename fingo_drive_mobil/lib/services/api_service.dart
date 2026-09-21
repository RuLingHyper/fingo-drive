// 1. KÜTÜPHANELER
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _defaultBaseUrl = "http://192.168.1.128:8000";

  // --- SUNUCU ADRESİNİ BULMA (DİNAMİK IP) ---
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedIp = prefs.getString('server_ip');

    if (savedIp == null || savedIp.isEmpty) {
      return _defaultBaseUrl;
    }

    savedIp = savedIp.replaceAll(' ', '').replaceAll(',', '.');

    if (!savedIp.startsWith("http")) {
      savedIp = "http://$savedIp";
    }

    if (!savedIp.contains(":8000")) {
      if (savedIp.split(':').length < 3) {
        savedIp = "$savedIp:8000";
      }
    }

    if (savedIp.endsWith('/')) {
      savedIp = savedIp.substring(0, savedIp.length - 1);
    }
    return savedIp;
  }

  // --- DOSYA İNDİRME LİNKİ OLUŞTURMA ---
  static Future<String> getFileUrl(String username, String path) async {
    String baseUrl = await getBaseUrl();
    String encodedPath = Uri.encodeComponent(path).replaceAll('%2F', '/');
    return "$baseUrl/api/file/$username/$encodedPath";
  }

  // --- GİRİŞ YAPMA (LOGIN) ---
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 10));

      var data = json.decode(response.body);
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('username', data['username']);
        await prefs.setString('email', data['email']);
        return {'success': true, 'message': data['mesaj'], 'data': data};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? "Giriş başarısız"
        };
      }
    } catch (e) {
      return {'success': false, 'message': "Sunucuya ulaşılamadı."};
    }
  }

  // --- DOĞRULAMA KODU GÖNDERME ---
  static Future<Map<String, dynamic>> sendVerificationCode(
      String email, String username) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/send_verification_code'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "username": username}),
      );

      var data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['detail'] ?? data['mesaj']};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? "Bir hata oluştu"
        };
      }
    } catch (e) {
      return {'success': false, 'message': "Sunucu hatası: $e"};
    }
  }

  // --- KODU DOĞRULAYIP KAYDI TAMAMLAMA ---
  static Future<Map<String, dynamic>> verifyAndRegister(
      String username, String email, String password, String code) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/verify_and_register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
          "code": code
        }),
      );

      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['detail'] ?? data['mesaj'] ?? "Kayıt Başarılı"
        };
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? "Kayıt başarısız"
        };
      }
    } catch (e) {
      return {'success': false, 'message': "Bağlantı hatası: $e"};
    }
  }

  // --- PROFİL GÜNCELLEME ---
  static Future<Map<String, dynamic>> updateSingleProfile(
      String oldUsername, String target, String newValue) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/update_profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'old_username': oldUsername,
          'target': target,
          'new_value': newValue
        }),
      );

      var data = json.decode(response.body);
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        if (data['username'] != null) {
          await prefs.setString('username', data['username']);
        }
        if (data['email'] != null) {
          await prefs.setString('email', data['email']);
        }
        return {'success': true, 'message': "Güncellendi"};
      } else {
        return {'success': false, 'message': data['detail'] ?? "Hata"};
      }
    } catch (e) {
      return {'success': false, 'message': "Bağlantı hatası"};
    }
  }

  // --- E-POSTA DEĞİŞTİRME (ADIM 1: KOD İSTE) ---
  static Future<Map<String, dynamic>> requestEmailChange(
      String username, String newEmail) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/request_email_change'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "new_email": newEmail}),
      );
      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['detail'] ?? data['mesaj']};
      } else {
        return {'success': false, 'message': data['detail'] ?? "Hata"};
      }
    } catch (e) {
      return {'success': false, 'message': "Sunucu hatası"};
    }
  }

  // --- E-POSTA DEĞİŞTİRME (ADIM 2: ONAYLA) ---
  static Future<Map<String, dynamic>> confirmEmailChange(
      String username, String newEmail, String code) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/confirm_email_change'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
            {"username": username, "new_email": newEmail, "code": code}),
      );
      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('email', newEmail);
        return {'success': true, 'message': data['mesaj']};
      } else {
        return {'success': false, 'message': data['detail'] ?? "Hata"};
      }
    } catch (e) {
      return {'success': false, 'message': "Bağlantı hatası"};
    }
  }

  // --- HESAP SİLME (ADIM 1: KOD İSTE) ---
  static Future<Map<String, dynamic>> requestAccountDeletion(
      String username) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/request_account_deletion'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username}),
      );
      var data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['detail'] ?? data['mesaj']};
      } else {
        return {'success': false, 'message': data['detail'] ?? "Hata"};
      }
    } catch (e) {
      return {'success': false, 'message': "Sunucu hatası"};
    }
  }

  // --- HESAP SİLME (ADIM 2: KESİN SİL) ---
  static Future<bool> confirmAccountDeletion(
      String username, String code) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.delete(
          Uri.parse('$baseUrl/api/confirm_account_deletion/$username/$code'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- DOSYALARI LİSTELEME ---
  static Future<Map<String, dynamic>> listFiles(
      String username, String path) async {
    String baseUrl = await getBaseUrl();
    String queryString = Uri(queryParameters: {
      'username': username,
      'path': path,
      't': DateTime.now().millisecondsSinceEpoch.toString()
    }).query;

    try {
      var response = await http
          .get(Uri.parse('$baseUrl/api/files?$queryString'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      } else {
        return {'success': false, 'message': "Hata: ${response.statusCode}"};
      }
    } catch (e) {
      return {'success': false, 'message': "Bağlantı Hatası"};
    }
  }

  // --- YENİ KLASÖR OLUŞTURMA ---
  static Future<bool> createFolder(
      String username, String path, String folderName) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/create_folder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'username': username, 'path': path, 'folder_name': folderName}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- DOSYA VEYA KLASÖR SİLME ---
  static Future<bool> deleteItem(String username, String fullPath) async {
    String baseUrl = await getBaseUrl();
    String encodedPath = Uri.encodeComponent(fullPath).replaceAll('%2F', '/');
    try {
      var response = await http
          .delete(Uri.parse('$baseUrl/api/delete/$username/$encodedPath'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- DOSYA İSMİ DEĞİŞTİRME ---
  static Future<Map<String, dynamic>> renameItem(
      String username, String path, String oldName, String newName) async {
    String baseUrl = await getBaseUrl();
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/rename'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'path': path,
          'old_name': oldName,
          'new_name': newName
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        var data = json.decode(response.body);
        return {
          'success': false,
          'message': data['detail'] ?? "İsim değiştirilemedi"
        };
      }
    } catch (e) {
      return {'success': false, 'message': "Bağlantı hatası"};
    }
  }

  // --- ŞİFREMİ UNUTTUM (ADIM 1: KOD İSTE) ---
  static Future<void> requestPasswordReset(String email) async {
    String baseUrl = await getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/api/request_password_reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      String errorMsg = 'Bir hata oluştu';
      try {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        if (error is Map) {
          errorMsg = error['detail'] ?? error['mesaj'] ?? errorMsg;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  // --- ŞİFREMİ UNUTTUM (ADIM 2: ONAYLA VE DEĞİŞTİR) ---
  static Future<void> confirmPasswordReset(
      String email, String code, String newPassword) async {
    String baseUrl = await getBaseUrl();
    final response = await http.post(
      Uri.parse('$baseUrl/api/confirm_password_reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email, 'code': code, 'new_password': newPassword}),
    );

    if (response.statusCode != 200) {
      String errorMsg = 'Şifre değiştirilemedi';
      try {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        if (error is Map) {
          errorMsg = error['detail'] ?? error['mesaj'] ?? errorMsg;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}
