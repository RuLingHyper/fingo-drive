// ignore_for_file: use_build_context_synchronously, deprecated_member_use

// --- KÜTÜPHANELER ---
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fingo_drive_mobil/screens/login_screen.dart';
import 'package:fingo_drive_mobil/services/api_service.dart';
import 'package:fingo_drive_mobil/screens/settings_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:open_filex/open_filex.dart';

// --- ANA EKRAN (StatefulWidget) ---
class HomeScreen extends StatefulWidget {
  final String token;
  final String username;

  const HomeScreen({super.key, required this.token, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- DEĞİŞKENLER ---
  List tumDosyalar = [];
  List gosterilenDosyalar = [];
  String kullanilanAlanStr = "0 B";
  double kullanilanAlanOran = 0.0;
  bool yukleniyor = true;
  String aramaMetni = "";
  String secilenKategori = "Hepsi";
  String siralamaTuru = "tarih_yeni";
  String mevcutYol = "";
  final TextEditingController _aramaController = TextEditingController();

  // --- BAŞLANGIÇ ---
  @override
  void initState() {
    super.initState();
    _dosyalariGetir();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  // --- DOSYALARI SUNUCUDAN ÇEKME ---
  Future<void> _dosyalariGetir() async {
    if (!mounted) return;
    setState(() => yukleniyor = true);

    var sonuc = await ApiService.listFiles(widget.username, mevcutYol);

    if (!mounted) return;

    if (sonuc['success']) {
      var veri = sonuc['data'];
      setState(() {
        tumDosyalar = veri['dosyalar'];

        var kullanim = veri['kullanim'] ?? {};
        double toplamByte = (kullanim['toplam_byte'] ?? 0).toDouble();
        double limitByte = (kullanim['limit_byte'] ?? 1073741824).toDouble();
        kullanilanAlanOran = (toplamByte / limitByte).clamp(0.0, 1.0);
        kullanilanAlanStr = kullanim['toplam_str'] ?? "0 B";

        yukleniyor = false;
        _listeyiFiltrele();
      });
    } else {
      setState(() => yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sonuc['message']),
          backgroundColor: Colors.red,
          action: SnackBarAction(
              label: "Tekrar",
              textColor: Colors.white,
              onPressed: _dosyalariGetir)));
    }
  }

  // --- DOSYAYI GEÇİCİ İNDİR VE AÇ (PDF, DOC vb.) ---
  Future<void> _dosyayiGeciciIndirVeAc(String url, String dosyaAdi) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Dosya hazırlanıyor..."),
        duration: Duration(seconds: 1),
      ));

      Directory tempDir = await getTemporaryDirectory();
      String savePath = "${tempDir.path}/$dosyaAdi";

      await Dio().download(url, savePath);

      var result = await OpenFilex.open(savePath);

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Açılamadı: ${result.message}"),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Dosya açılırken hata oluştu"),
            backgroundColor: Colors.red));
      }
    }
  }

  // --- DOSYAYA ÖNİZLEME ---
  void _dosyaOnizle(Map<String, dynamic> dosya) async {
    String tamYol =
        mevcutYol.isEmpty ? dosya['isim'] : "$mevcutYol/${dosya['isim']}";
    String url = await ApiService.getFileUrl(widget.username, tamYol);
    String tur = dosya['tur'];

    if (!mounted) return;

    if (tur == 'resim') {
      showDialog(
          context: context,
          builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(alignment: Alignment.center, children: [
                InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
                Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(ctx)))
              ])));
    } else if (tur == 'muzik') {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => SesCalarDialog(url: url, dosyaIsmi: dosya['isim']));
    } else if (tur == 'video') {
      showDialog(
          context: context,
          builder: (ctx) =>
              VideoOynaticiDialog(url: url, dosyaIsmi: dosya['isim']));
    } else {
      _dosyayiGeciciIndirVeAc(url, dosya['isim']);
    }
  }

  // --- YENİ KLASÖR OLUŞTURMA ---
  Future<void> _klasorOlustur(String ad) async {
    if (ad.isEmpty) return;
    setState(() => yukleniyor = true);
    bool basarili =
        await ApiService.createFolder(widget.username, mevcutYol, ad);

    if (!mounted) return;

    if (basarili) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("📁 Klasör oluşturuldu"),
          backgroundColor: Colors.green));
      _dosyalariGetir();
    } else {
      setState(() => yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Hata oluştu"), backgroundColor: Colors.red));
    }
  }

  // --- DOSYA SİLME ---
  Future<void> _dosyaSil(String dosyaAdi) async {
    String tamYol = mevcutYol.isEmpty ? dosyaAdi : "$mevcutYol/$dosyaAdi";
    bool? onay = await showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Silinsin mi?"),
              content: Text("'$dosyaAdi' kalıcı olarak silinecek."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text("İptal")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text("Sil")),
              ],
            ));

    if (onay == true) {
      bool basarili = await ApiService.deleteItem(widget.username, tamYol);
      if (!mounted) return;

      if (basarili) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("🗑️ Silindi"), backgroundColor: Colors.orange));
        _dosyalariGetir();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Silinemedi"), backgroundColor: Colors.red));
      }
    }
  }

  // --- DOSYA YENİDEN ADLANDIRMA ---
  Future<void> _dosyaYenidenAdlandir(String eskiIsim, String yeniIsim) async {
    if (yeniIsim.isEmpty || eskiIsim == yeniIsim) return;
    setState(() => yukleniyor = true);
    var sonuc = await ApiService.renameItem(
        widget.username, mevcutYol, eskiIsim, yeniIsim);

    if (!mounted) return;

    if (sonuc['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ İsim değiştirildi"), backgroundColor: Colors.green));
      _dosyalariGetir();
    } else {
      setState(() => yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Hata: ${sonuc['message']}"),
          backgroundColor: Colors.red));
    }
  }

  // --- DOSYA YÜKLEME (UPLOAD) ---
  Future<void> _dosyaYukle() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) return;

    List<PlatformFile> validFiles =
        result.files.where((f) => f.path != null).toList();
    if (validFiles.isEmpty) return;

    ValueNotifier<double> ilerleme = ValueNotifier(0.0);
    ValueNotifier<String> durumBasligi =
        ValueNotifier("Yükleniyor (1/${validFiles.length})");

    if (mounted) _yuklemeDialogGoster(durumBasligi, ilerleme);

    int basariliSayac = 0;
    String? sonHata;

    for (int i = 0; i < validFiles.length; i++) {
      PlatformFile file = validFiles[i];
      durumBasligi.value =
          "${file.name} (${i + 1}/${validFiles.length})";
      ilerleme.value = 0.0;

      try {
        String baseUrl = await ApiService.getBaseUrl();
        String uploadUrl = "$baseUrl/api/upload";
        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(file.path!, filename: file.name),
          "username": widget.username,
          "path": mevcutYol,
        });

        await Dio().post(uploadUrl,
            data: formData, onSendProgress: (s, t) => ilerleme.value = s / t);

        basariliSayac++;
      } catch (e) {
        sonHata = e.toString();
      }
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (basariliSayac == validFiles.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ $basariliSayac dosya başarıyla yüklendi!"),
          backgroundColor: Colors.green));
    } else if (basariliSayac > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "⚠️ $basariliSayac/${validFiles.length} dosya yüklendi. Bazı dosyalar yüklenemedi: $sonHata"),
          backgroundColor: Colors.orange));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Hata: $sonHata"), backgroundColor: Colors.red));
    }

    _dosyalariGetir();
  }

  // --- DOSYA İNDİRME ---
  Future<void> _dosyaIndir(String dosyaAdi) async {
    if (!await _izinIste()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("İzin gerekli!"), backgroundColor: Colors.orange));
      return;
    }
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("İndirme başlatıldı..."),
          duration: Duration(seconds: 1)));

      String savePath = await _kayitYoluGetir(dosyaAdi, false);
      String tamYol = mevcutYol.isEmpty ? dosyaAdi : "$mevcutYol/$dosyaAdi";
      String downloadUrl = await ApiService.getFileUrl(widget.username, tamYol);

      await Dio().download(downloadUrl, savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("İndirildi: $savePath"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  // --- KLASÖRÜ ZIP OLARAK İNDİRME ---
  Future<void> _klasorIndir(String klasorAdi) async {
    if (!await _izinIste()) return;
    setState(() => yukleniyor = true);
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Klasör sıkıştırılıp indiriliyor...")));

      String savePath = await _kayitYoluGetir("$klasorAdi.zip", false);
      String baseUrl = await ApiService.getBaseUrl();
      await Dio()
          .post(
            "$baseUrl/api/download_folder",
            data: {
              "username": widget.username,
              "path": mevcutYol,
              "folder_name": klasorAdi
            },
            options: Options(responseType: ResponseType.bytes),
          )
          .then((r) => File(savePath).writeAsBytesSync(r.data));

      if (!mounted) return;
      setState(() => yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Klasör İndirildi: $savePath"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      setState(() => yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Klasör indirilemedi"), backgroundColor: Colors.red));
    }
  }

  // --- PAYLAŞIM SEÇENEKLERİ ---
  void _paylasSecenekleri(String dosyaAdi, bool isKlasor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Dosya Olarak Paylaş
              ListTile(
                leading: const Icon(Icons.file_present,
                    color: Colors.indigo, size: 30),
                title: Text(
                    isKlasor ? "Klasörü Paylaş (ZIP)" : "Dosya Olarak Paylaş",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Dosyayı karşı tarafa gönderir"),
                onTap: () {
                  Navigator.pop(context);
                  _paylasDosya(dosyaAdi, isKlasor);
                },
              ),
              // 2. Link Olarak Paylaş
              if (!isKlasor) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue, size: 30),
                  title: const Text("Link Paylaş",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("İndirme bağlantısını gönderir"),
                  onTap: () {
                    Navigator.pop(context);
                    _paylasLink(dosyaAdi);
                  },
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  // --- DOSYAYI PAYLAŞ ---
  Future<void> _paylasDosya(String dosyaAdi, bool isKlasor) async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Dosya hazırlanıyor...")));

      Directory tempDir = await getTemporaryDirectory();
      String tempPath = "${tempDir.path}/$dosyaAdi${isKlasor ? '.zip' : ''}";
      if (File(tempPath).existsSync()) File(tempPath).deleteSync();

      if (isKlasor) {
        String baseUrl = await ApiService.getBaseUrl();
        await Dio()
            .post(
              "$baseUrl/api/download_folder",
              data: {
                "username": widget.username,
                "path": mevcutYol,
                "folder_name": dosyaAdi
              },
              options: Options(responseType: ResponseType.bytes),
            )
            .then((r) => File(tempPath).writeAsBytesSync(r.data));
      } else {
        String tamYol = mevcutYol.isEmpty ? dosyaAdi : "$mevcutYol/$dosyaAdi";
        String downloadUrl =
            await ApiService.getFileUrl(widget.username, tamYol);
        await Dio().download(downloadUrl, tempPath);
      }

      if (await File(tempPath).exists()) {
        await Share.shareXFiles([XFile(tempPath)],
            text: "Fingo Drive'dan bir dosya: $dosyaAdi");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Paylaşılamadı!"), backgroundColor: Colors.red));
    }
  }

  // --- LİNK PAYLAŞMA ---
  Future<void> _paylasLink(String dosyaAdi) async {
    try {
      String tamYol = mevcutYol.isEmpty ? dosyaAdi : "$mevcutYol/$dosyaAdi";
      String url = await ApiService.getFileUrl(widget.username, tamYol);
      String mesaj =
          "Fingo Drive Dosyası:\n$dosyaAdi\n\nTıklayıp izle veya indir:\n$url";

      await Share.share(mesaj);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Link oluşturulamadı")));
    }
  }

  // --- ÇIKIŞ YAPMA ---
  void _cikisYap() {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Çıkış"),
              content: const Text("Çıkış yapmak istediğine emin misin?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("İptal")),
                ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (mounted) {
                        Navigator.pop(c);
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (c) => const LoginScreen()));
                      }
                    },
                    child: const Text("Çıkış Yap")),
              ],
            ));
  }

  // --- YARDIMCI: BOYUT FORMATLAMA (MB, GB) ---
  String _boyutStr(dynamic dosya) {
    if (dosya['boyut_str'] != null && dosya['boyut_str'] != 'null') {
      return dosya['boyut_str'];
    }
    if (dosya['boyut'] != null) {
      int b = int.tryParse(dosya['boyut'].toString()) ?? 0;
      if (b < 1024) return "$b B";
      if (b < 1048576) return "${(b / 1024).toStringAsFixed(1)} KB";
      return "${(b / 1048576).toStringAsFixed(1)} MB";
    }
    return "Bilinmiyor";
  }

  // --- DOSYA BİLGİ PENCERESİ ---
  void _dosyaBilgileriGoster(Map<String, dynamic> dosya) {
    bool isKlasor = dosya['tur'] == 'klasor';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.info, color: Colors.indigo),
          SizedBox(width: 10),
          Text("Dosya Bilgisi")
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bilgiSatiri("Adı:", dosya['isim']),
            const Divider(),
            _bilgiSatiri("Boyutu:", _boyutStr(dosya)),
            const Divider(),
            _bilgiSatiri(isKlasor ? "Oluşturulma:" : "Yükleme Tarihi:",
                dosya['tarih'] ?? "-"),
            const Divider(),
            _bilgiSatiri("Tür:", dosya['tur'].toString().toUpperCase()),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Tamam"))
        ],
      ),
    );
  }

  Widget _bilgiSatiri(String baslik, String deger) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 80,
              child: Text(baslik,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(deger, style: const TextStyle(fontSize: 15)))
        ]));
  }

  // --- İZİN İSTEME (Android) ---
  Future<bool> _izinIste() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.manageExternalStorage.request().isGranted) return true;
      if (await Permission.photos.request().isGranted) return true;
      if (await Permission.videos.request().isGranted) return true;
      if (await Permission.audio.request().isGranted) return true;
      return true; // Uygulama dizinine indirme yapılabilmesi için devam et
    }
    return true;
  }

  // --- İNDİRİLECEK DOSYA YOLUNU BULMA ---
  Future<String> _kayitYoluGetir(String dosyaAdi, bool isTemp) async {
    if (isTemp) {
      Directory t = await getTemporaryDirectory();
      return "${t.path}/$dosyaAdi";
    }
    Directory? dir;
    if (Platform.isAndroid) {
      try {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } catch (_) {
        dir = await getExternalStorageDirectory();
      }
    }
    dir ??= await getApplicationDocumentsDirectory();
    String savePath = "${dir.path}/$dosyaAdi";
    int sayac = 1;
    String kok = dosyaAdi.contains('.')
        ? dosyaAdi.substring(0, dosyaAdi.lastIndexOf('.'))
        : dosyaAdi;
    String ext = dosyaAdi.contains('.')
        ? dosyaAdi.substring(dosyaAdi.lastIndexOf('.'))
        : "";
    while (File(savePath).existsSync()) {
      savePath = "${dir.path}/$kok ($sayac)$ext";
      sayac++;
    }
    return savePath;
  }

  // --- YÜKLEME PENCERESİ ---
  void _yuklemeDialogGoster(
      ValueNotifier<String> baslik, ValueNotifier<double> ilerleme) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
            title: ValueListenableBuilder<String>(
              valueListenable: baslik,
              builder: (context, val, child) => Text(val,
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              ValueListenableBuilder<double>(
                  valueListenable: ilerleme,
                  builder: (context, value, child) => Column(children: [
                        Text("%${(value * 100).toStringAsFixed(0)}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.indigo)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                            value: value,
                            color: Colors.indigo,
                            backgroundColor: Colors.indigo.shade100)
                      ])),
            ])));
  }

  // --- TÜRKÇE KARAKTER TEMİZLEME (Arama İçin) ---
  String _trKarakterTemizle(String metin) {
    return metin
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  // --- LİSTEYİ FİLTRELEME VE SIRALAMA (Arama ve Kategori) ---
  void _listeyiFiltrele() {
    var geciciListe = tumDosyalar.where((dosya) {
      String isim = _trKarakterTemizle(dosya['isim']);
      String aranan = _trKarakterTemizle(aramaMetni);
      bool aramaOk = isim.contains(aranan);

      bool katOk = true;
      String tur = dosya['tur'];

      if (secilenKategori == "Hepsi") {
        katOk = true;
      } else if (secilenKategori == "Resim") {
        katOk = (tur == 'resim');
      } else if (secilenKategori == "Video") {
        katOk = (tur == 'video');
      } else if (secilenKategori == "Ses") {
        katOk = (tur == 'muzik');
      } else if (secilenKategori == "Diğer") {
        katOk = !['resim', 'video', 'muzik'].contains(tur);
      }

      return aramaOk && katOk;
    }).toList();

    geciciListe.sort((a, b) {
      if (a['tur'] == 'klasor' && b['tur'] != 'klasor') return -1;
      if (a['tur'] != 'klasor' && b['tur'] == 'klasor') return 1;
      switch (siralamaTuru) {
        case 'tarih_yeni':
          return _tarihParse(b['tarih']).compareTo(_tarihParse(a['tarih']));
        case 'tarih_eski':
          return _tarihParse(a['tarih']).compareTo(_tarihParse(b['tarih']));
        case 'boyut_buyuk':
          return (b['boyut'] ?? 0).compareTo(a['boyut'] ?? 0);
        case 'boyut_kucuk':
          return (a['boyut'] ?? 0).compareTo(b['boyut'] ?? 0);
        default:
          return 0;
      }
    });

    setState(() {
      gosterilenDosyalar = geciciListe;
    });
  }

  // --- TARİH DÖNÜŞTÜRME YARDIMCISI ---
  DateTime _tarihParse(String? t) {
    if (t == null) return DateTime(1970);
    try {
      var parts = t.split(' ');
      var d = parts[0].split('.');
      var time = parts[1].split(':');
      return DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0]),
          int.parse(time[0]), int.parse(time[1]));
    } catch (e) {
      return DateTime(1970);
    }
  }

  // --- İKON RENKLERİ ---
  Map<String, dynamic> _ikonGetir(String tur) {
    switch (tur) {
      case 'resim':
        return {'icon': Icons.image, 'color': Colors.purple};
      case 'video':
        return {'icon': Icons.play_circle_fill, 'color': Colors.red};
      case 'muzik':
        return {'icon': Icons.music_note, 'color': Colors.pink};
      case 'pdf':
        return {'icon': Icons.picture_as_pdf, 'color': Colors.redAccent};
      case 'belge':
        return {'icon': Icons.description, 'color': Colors.blue};
      case 'sunum':
        return {'icon': Icons.slideshow, 'color': Colors.deepOrange};
      case 'excel':
        return {'icon': Icons.table_chart, 'color': Colors.green};
      case 'arsiv':
        return {'icon': Icons.folder_zip, 'color': Colors.amber};
      case 'kod':
        return {'icon': Icons.code, 'color': Colors.black87};
      default:
        return {'icon': Icons.insert_drive_file, 'color': Colors.blueGrey};
    }
  }

  // --- GERİ TUŞUNA BASINCA ---
  void _geriCik() {
    if (mevcutYol.isNotEmpty) {
      setState(() => mevcutYol = mevcutYol.contains('/')
          ? mevcutYol.substring(0, mevcutYol.lastIndexOf('/'))
          : "");
      _dosyalariGetir();
    }
  }

  // --- KLASÖRE TIKLAYINCA ---
  void _klasoreGir(String ad) {
    setState(() => mevcutYol = mevcutYol.isEmpty ? ad : "$mevcutYol/$ad");
    _dosyalariGetir();
  }

  // --- KLASÖR OLUŞTURMA PENCERESİ ---
  Future<void> _klasorOlusturDialog() async {
    TextEditingController c = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Yeni Klasör"),
                content: TextField(
                    controller: c,
                    decoration: const InputDecoration(
                        hintText: "Klasör Adı", border: OutlineInputBorder())),
                actions: [
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _klasorOlustur(c.text);
                      },
                      child: const Text("Oluştur"))
                ]));
  }

  // --- YENİDEN ADLANDIRMA PENCERESİ ---
  Future<void> _dosyaYenidenAdlandirDialog(String eskiIsim) async {
    String uzanti = eskiIsim.contains('.')
        ? eskiIsim.substring(eskiIsim.lastIndexOf('.'))
        : "";
    String kok = eskiIsim.contains('.')
        ? eskiIsim.substring(0, eskiIsim.lastIndexOf('.'))
        : eskiIsim;
    TextEditingController c = TextEditingController(text: kok);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Yeniden Adlandır"),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: c,
                      decoration:
                          const InputDecoration(labelText: "Yeni İsim")),
                  if (uzanti.isNotEmpty)
                    Text("Uzantı ($uzanti) korunacak.",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey))
                ]),
                actions: [
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _dosyaYenidenAdlandir(eskiIsim, c.text + uzanti);
                      },
                      child: const Text("Kaydet"))
                ]));
  }

  // --- EKRAN TASARIMI ---
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: mevcutYol.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _geriCik();
        },
        child: Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Fingo Drive",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Row(children: [
                    const Icon(Icons.person, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(widget.username,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70))
                  ]),
                ]),
                Expanded(
                  child: Text(
                    mevcutYol.isEmpty ? "/(Ana Dizin)" : "/$mevcutYol",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: "Sıralama",
                onSelected: (val) {
                  setState(() {
                    siralamaTuru = val;
                    _listeyiFiltrele();
                  });
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                      value: "tarih_yeni",
                      child: Text("📅 Tarih (Yeni > Eski)")),
                  const PopupMenuItem(
                      value: "tarih_eski",
                      child: Text("📅 Tarih (Eski > Yeni)")),
                  const PopupMenuItem(
                      value: "boyut_buyuk",
                      child: Text("💾 Boyut (Büyük > Küçük)")),
                  const PopupMenuItem(
                      value: "boyut_kucuk",
                      child: Text("💾 Boyut (Küçük > Büyük)")),
                ],
              ),
              IconButton(
                  icon: const Icon(Icons.refresh), onPressed: _dosyalariGetir),
              IconButton(
                icon: const Icon(Icons.manage_accounts),
                tooltip: "Profil Ayarları",
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                              currentUsername: widget.username)));
                },
              ),
              IconButton(icon: const Icon(Icons.logout), onPressed: _cikisYap),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                decoration: const BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30))),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Depolama",
                            style: TextStyle(color: Colors.white70)),
                        Text(kullanilanAlanStr,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))
                      ]),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                      value: kullanilanAlanOran,
                      backgroundColor: Colors.indigo.shade300,
                      color: kullanilanAlanOran > 0.9
                          ? Colors.redAccent
                          : (kullanilanAlanOran > 0.7
                              ? Colors.amber
                              : Colors.orangeAccent),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10)),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _aramaController,
                      onChanged: (v) {
                        setState(() {
                          aramaMetni = v;
                          _listeyiFiltrele();
                        });
                      },
                      decoration: InputDecoration(
                          hintText: "Dosya ara...",
                          fillColor: Colors.white,
                          filled: true,
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.indigo),
                          suffixIcon: aramaMetni.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      aramaMetni = "";
                                      _aramaController.clear();
                                      _listeyiFiltrele();
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: ["Hepsi", "Resim", "Video", "Ses", "Diğer"]
                            .map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: ChoiceChip(
                                    label: Text(e),
                                    selected: secilenKategori == e,
                                    onSelected: (v) {
                                      setState(() {
                                        secilenKategori = e;
                                        _listeyiFiltrele();
                                      });
                                    },
                                    selectedColor: Colors.orangeAccent
                                        .withValues(alpha: 0.4),
                                    backgroundColor: Colors.white)))
                            .toList())),
              ),
              if (mevcutYol.isNotEmpty)
                Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    color: Colors.indigo.shade50,
                    child: ListTile(
                        leading: const Icon(Icons.arrow_upward,
                            color: Colors.indigo),
                        title: const Text("... Üst Klasör",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo)),
                        onTap: _geriCik)),
              Expanded(
                child: yukleniyor
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _dosyalariGetir,
                        color: Colors.indigo,
                        child: gosterilenDosyalar.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.4,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.folder_off,
                                            size: 60, color: Colors.grey[300]),
                                        const SizedBox(height: 10),
                                        const Text("Klasör Boş",
                                            style: TextStyle(color: Colors.grey))
                                      ],
                                    ),
                                  )
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(10),
                                itemCount: gosterilenDosyalar.length,
                                itemBuilder: (context, index) {
                                  var dosya = gosterilenDosyalar[index];
                                  bool isKlasor = dosya['tur'] == 'klasor';
                                  var ikonBilgi = isKlasor
                                      ? {
                                          'icon': Icons.folder,
                                          'color': Colors.orange
                                        }
                                      : _ikonGetir(dosya['tur']);

                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                          backgroundColor:
                                              (ikonBilgi['color'] as Color)
                                                  .withValues(alpha: 0.1),
                                          child: Icon(ikonBilgi['icon'],
                                              color: ikonBilgi['color'])),
                                      title: Text(dosya['isim'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                          isKlasor
                                              ? "Klasör"
                                              : "${_boyutStr(dosya)} • ${dosya['tarih']}",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600])),
                                      onTap: () => isKlasor
                                          ? _klasoreGir(dosya['isim'])
                                          : _dosyaOnizle(dosya),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (val) {
                                          if (val == 'bilgi') {
                                            _dosyaBilgileriGoster(dosya);
                                          }
                                          if (val == 'indir') {
                                            isKlasor
                                                ? _klasorIndir(dosya['isim'])
                                                : _dosyaIndir(dosya['isim']);
                                          }
                                          if (val == 'paylas') {
                                            _paylasSecenekleri(
                                                dosya['isim'], isKlasor);
                                          }
                                          if (val == 'adlandir') {
                                            _dosyaYenidenAdlandirDialog(
                                                dosya['isim']);
                                          }
                                          if (val == 'sil') {
                                            _dosyaSil(dosya['isim']);
                                          }
                                        },
                                        itemBuilder: (c) =>
                                            <PopupMenuEntry<String>>[
                                          const PopupMenuItem(
                                              value: 'bilgi',
                                              child: Row(children: [
                                                Icon(Icons.info_outline,
                                                    color: Colors.blueGrey),
                                                SizedBox(width: 8),
                                                Text("Bilgi")
                                              ])),
                                          const PopupMenuItem(
                                              value: 'indir',
                                              child: Row(children: [
                                                Icon(Icons.download,
                                                    color: Colors.green),
                                                SizedBox(width: 8),
                                                Text("İndir")
                                              ])),
                                          const PopupMenuItem(
                                              value: 'paylas',
                                              child: Row(children: [
                                                Icon(Icons.share,
                                                    color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text("Paylaş")
                                              ])),
                                          const PopupMenuItem(
                                              value: 'adlandir',
                                              child: Row(children: [
                                                Icon(Icons.edit,
                                                    color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text("Adlandır")
                                              ])),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                              value: 'sil',
                                              child: Row(children: [
                                                Icon(Icons.delete,
                                                    color: Colors.red),
                                                SizedBox(width: 8),
                                                Text("Sil",
                                                    style: TextStyle(
                                                        color: Colors.red))
                                              ])),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.indigo,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (c) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                          leading: const Icon(Icons.create_new_folder,
                              color: Colors.orange, size: 30),
                          title: const Text("Klasör Oluştur",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.pop(c);
                            _klasorOlusturDialog();
                          }),
                      ListTile(
                          leading: const Icon(Icons.upload_file,
                              color: Colors.blue, size: 30),
                          title: const Text("Dosya Yükle",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.pop(c);
                            _dosyaYukle();
                          }),
                    ]))),
          ),
        ),
      ),
    );
  }
}

// --- VİDEO OYNATICI EKRANI ---
class VideoOynaticiDialog extends StatefulWidget {
  final String url;
  final String dosyaIsmi;
  const VideoOynaticiDialog(
      {super.key, required this.url, required this.dosyaIsmi});
  @override
  State<VideoOynaticiDialog> createState() => _VideoOynaticiDialogState();
}

class _VideoOynaticiDialogState extends State<VideoOynaticiDialog> {
  late VideoPlayerController _c;
  ChewieController? _cc;
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _c.initialize();
      if (!mounted) return;
      setState(() {
        _cc = ChewieController(
            videoPlayerController: _c, autoPlay: true, looping: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = "Video oynatılamadı: $e";
      });
    }
  }

  @override
  void dispose() {
    if (!_hasError) {
      _c.dispose();
      _cc?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return AlertDialog(
        title: const Text("Oynatma Hatası"),
        content: Text(_errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat"),
          )
        ],
      );
    }
    return Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: _cc != null
            ? AspectRatio(
                aspectRatio: _c.value.aspectRatio,
                child: Chewie(controller: _cc!))
            : const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ));
  }
}

// --- MÜZİK ÇALAR EKRANI ---
class SesCalarDialog extends StatefulWidget {
  final String url;
  final String dosyaIsmi;
  const SesCalarDialog({super.key, required this.url, required this.dosyaIsmi});

  @override
  State<SesCalarDialog> createState() => _SesCalarDialogState();
}

class _SesCalarDialogState extends State<SesCalarDialog> {
  final AudioPlayer _p = AudioPlayer();
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool isComplete = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _p.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _p.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _p.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() {
          isPlaying = s == PlayerState.playing;
          if (s == PlayerState.completed) {
            isComplete = true;
            isPlaying = false;
            _position = Duration.zero;
          }
        });
      }
    });

    try {
      await _p.setSourceUrl(widget.url);
    } catch (e) {
      debugPrint("Ses Hatası: $e");
    }
  }

  @override
  void dispose() {
    _p.stop();
    _p.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _togglePlay() async {
    try {
      if (isPlaying) {
        await _p.pause();
      } else {
        if (isComplete ||
            (_position.inSeconds >= _duration.inSeconds &&
                _duration.inSeconds > 0)) {
          setState(() {
            isComplete = false;
            _position = Duration.zero;
          });
          await _p.play(UrlSource(widget.url));
        } else {
          await _p.resume();
        }
      }
    } catch (e) {
      debugPrint("Oynatma Hatası: $e");
      await _p.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxVal = _duration.inSeconds.toDouble();
    double currentVal = _position.inSeconds.toDouble();

    if (maxVal <= 0) maxVal = 1.0;
    if (currentVal > maxVal) currentVal = maxVal;
    if (currentVal < 0) currentVal = 0.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(children: [
        const Icon(Icons.music_note, size: 40, color: Colors.indigo),
        const SizedBox(height: 10),
        Text(widget.dosyaIsmi,
            style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Slider(
          min: 0,
          max: maxVal,
          value: currentVal,
          activeColor: Colors.indigo,
          onChanged: (maxVal > 1.0)
              ? (value) async {
                  final newPos = Duration(seconds: value.toInt());
                  setState(() {
                    _position = newPos;
                    isComplete = false;
                  });

                  try {
                    await _p.seek(newPos);
                    if (!isPlaying) await _p.resume();
                  } catch (e) {
                    await _p.play(UrlSource(widget.url));
                    await _p.seek(newPos);
                  }
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(_position),
                  style: const TextStyle(fontSize: 12)),
              Text((_duration.inSeconds > 0) ? _formatTime(_duration) : "--:--",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.indigo,
          child: IconButton(
            iconSize: 30,
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white),
            onPressed: _togglePlay,
          ),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("Kapat"))
      ],
    );
  }
}
