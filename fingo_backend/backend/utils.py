# ---------------------------------------------------------
# 1. KÜTÜPHANELERİN YÜKLENMESİ
# ---------------------------------------------------------
import os
import re
import math
from datetime import datetime, timedelta, timezone

# ---------------------------------------------------------
# 2. SABİT AYARLAR
# ---------------------------------------------------------
BASE_UPLOAD_DIR = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'uploads')
BASE_UPLOAD_FOLDER = BASE_UPLOAD_DIR  # Geriye dönük uyumluluk için
TR_TABLO = str.maketrans("ğĞüÜşŞıİöÖçÇ", "gGuUsSiIoOcC")

# ---------------------------------------------------------
# 3. FONKSİYON: DOSYA İSMİNİ TEMİZLEME
# ---------------------------------------------------------
def dosya_ismini_temizle(isim: str) -> str:
    if not isim:
        return "isimsiz_dosya"
    isim = isim.translate(TR_TABLO)
    # Windows ve dosya sistemi için geçersiz karakterleri temizle
    isim = re.sub(r'[<>:"/\\|?*\x00-\x1f]', '_', isim)
    isim = isim.replace(" ", "_").strip('. ')
    return isim if isim else "isimsiz_dosya"

# ---------------------------------------------------------
# 4. FONKSİYON: GÜVENLİ DOSYA YOLU OLUŞTURMA
# ---------------------------------------------------------
def kullanici_yolu_getir(username: str, subpath: str = "") -> str:
    if not username:
        raise ValueError("Kullanıcı adı boş olamaz")
    
    clean_username = dosya_ismini_temizle(username)
    user_base = os.path.abspath(os.path.join(BASE_UPLOAD_DIR, clean_username))
    
    if not subpath:
        return user_base
        
    normalized_subpath = subpath.replace("\\", "/").strip("/")
    parts = [dosya_ismini_temizle(p) for p in normalized_subpath.split("/") if p and p != ".."]
    clean_subpath = os.path.join(*parts) if parts else ""
    
    target = os.path.abspath(os.path.join(user_base, clean_subpath))
    
    # Path traversal kontrolü: Hedef yol kesinlikle kullanıcının kök dizini altında olmalıdır
    if not target.startswith(user_base):
        raise ValueError("Geçersiz dizin yolu")
        
    return target

# ---------------------------------------------------------
# 4.1 FONKSİYON: KLASÖR ANAHTARI NORMALİZE ETME
# ---------------------------------------------------------
def normalize_folder_key(*parts: str) -> str:
    cleaned = []
    for part in parts:
        if part:
            for segment in str(part).replace("\\", "/").split("/"):
                seg_clean = segment.strip()
                if seg_clean and seg_clean != "..":
                    cleaned.append(seg_clean)
    return "/".join(cleaned)

# ---------------------------------------------------------
# 5. FONKSİYON: KLASÖR BOYUTU HESAPLAMA
# ---------------------------------------------------------
def get_folder_size(folder_path):
    total_size = 0
    try:
        if not os.path.exists(folder_path): return 0
        for dirpath, dirnames, filenames in os.walk(folder_path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if not os.path.islink(fp):
                    total_size += os.path.getsize(fp)
    except Exception:
        pass
    return total_size

# ---------------------------------------------------------
# 6. FONKSİYON: BOYUTU OKUNABİLİR YAPMA
# ---------------------------------------------------------
def dosya_boyutu_formatla(byte_boyutu):
    if byte_boyutu == 0: return "0 B"
    birimler = ("B", "KB", "MB", "GB", "TB")
    try:
        i = int(math.floor(math.log(byte_boyutu, 1024)))
        s = round(byte_boyutu / math.pow(1024, i), 2)
        return f"{s} {birimler[i]}"
    except ValueError:
        return "0 B"

# ---------------------------------------------------------
# 7. FONKSİYON: TARİHİ TÜRKİYE SAATİNE ÇEVİRME
# ---------------------------------------------------------
def formatla_tarih_tr(zaman_damgasi):
    try:
        utc_zaman = datetime.fromtimestamp(zaman_damgasi, timezone.utc)
        tr_zaman = utc_zaman + timedelta(hours=3)
        return tr_zaman.strftime('%d.%m.%Y %H:%M')
    except:
        return "-"
    
# ---------------------------------------------------------
# 8. FONKSİYON: DOSYA TÜRÜNÜ BELİRLEME
# ---------------------------------------------------------
def dosya_turu_belirle(dosya_adi, is_dir=False):
    if is_dir: return 'klasor'
    
    uzanti = dosya_adi.split('.')[-1].lower() if '.' in dosya_adi else ''
    
    tur_listesi = {
        'resim': {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'svg'},
        'video': {'mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv', '3gp'},
        'muzik': {'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg', 'wma'},
        'pdf':   {'pdf'},
        'belge': {'doc', 'docx', 'txt', 'rtf', 'odt'},
        'excel': {'xls', 'xlsx', 'csv', 'ods'},
        'sunum': {'ppt', 'pptx', 'odp'},
        'arsiv': {'zip', 'rar', '7z', 'tar', 'gz'},
        'kod':   {'py', 'dart', 'js', 'html', 'css', 'c', 'cpp', 'java', 'json', 'xml', 'sql', 'php'}
    }
    
    for tur, uzantilar in tur_listesi.items():
        if uzanti in uzantilar:
            return tur
            
    return 'dosya'