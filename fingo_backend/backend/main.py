# ---------------------------------------------------------
# 1. KÜTÜPHANELERİN YÜKLENMESİ 
# ---------------------------------------------------------
import os
import shutil
import zipfile
import io
import random
import re
import smtplib 
import mimetypes 
import hashlib
import secrets
import time
from email.message import EmailMessage
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select, delete

from database import engine, get_session, create_db_and_tables
from models import User, FolderMetadata
import utils

# ---------------------------------------------------------
# 2. BAŞLANGIÇ AYARLARI
# ---------------------------------------------------------
mimetypes.init()
mimetypes.add_type('audio/mp4', '.m4a')
mimetypes.add_type('audio/mpeg', '.mp3')
mimetypes.add_type('audio/wav', '.wav')
mimetypes.add_type('video/mp4', '.mp4')

SENDER_EMAIL = "fingodrive.destek@gmail.com" 
SENDER_PASSWORD = "ekoa mxxh pxjj sfmd" 

@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    if not os.path.exists(utils.BASE_UPLOAD_DIR):
        os.makedirs(utils.BASE_UPLOAD_DIR, exist_ok=True)
    yield

app = FastAPI(title="Fingo Drive API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

verification_codes = {}

# ---------------------------------------------------------
# 4. YARDIMCI FONKSİYONLAR
# ---------------------------------------------------------
@app.get("/")
def home():
    return {"message": "Fingo Drive API Çalışıyor! 🚀"}

def is_valid_email(email: str) -> bool:
    pattern = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return re.match(pattern, email) is not None

def send_email_notification(to_email: str, subject: str, message_body: str):
    try:
        msg = EmailMessage()
        msg.set_content(message_body)
        msg['Subject'] = subject
        msg['From'] = SENDER_EMAIL
        msg['To'] = to_email

        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.starttls()
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
            server.send_message(msg)
        print(f"📧 Mail gönderildi: {subject} -> {to_email}")
        return True
    except Exception as e:
        print(f"❌ Mail Hatası: {e}")
        return False

# ---------------------------------------------------------
# 4.1 ŞİFRE HASHLEME VE DOĞRULAMA YARDIMCILARI
# ---------------------------------------------------------
def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    hashed = hashlib.sha256((salt + password).encode()).hexdigest()
    return f"{salt}${hashed}"

def verify_password(stored_password: str, provided_password: str) -> bool:
    if not stored_password:
        return False
    if "$" in stored_password:
        salt, hashed = stored_password.split("$", 1)
        return hashlib.sha256((salt + provided_password).encode()).hexdigest() == hashed
    # Geriye dönük uyumluluk: Eski düz metin şifreler
    return stored_password == provided_password

def set_verification_code(key: str, code: str, ttl_seconds: int = 600):
    verification_codes[key] = {
        "code": str(code),
        "expires_at": time.time() + ttl_seconds
    }

def verify_code(key: str, code: str) -> bool:
    item = verification_codes.get(key)
    if not item:
        return False
    if time.time() > item.get("expires_at", 0):
        verification_codes.pop(key, None)
        return False
    return item.get("code") == str(code)

# ---------------------------------------------------------
# 5. KULLANICI İŞLEMLERİ (AUTH)
# ---------------------------------------------------------
@app.post("/api/send_verification_code")
def send_verification_code(data: dict, session: Session = Depends(get_session)):
    email = data.get("email")
    username = data.get("username")
    
    if not email or not is_valid_email(email): raise HTTPException(400, "Geçersiz E-posta adresi")
    
    if username:
        existing_user = session.exec(select(User).where((User.username == username) | (User.email == email))).first()
        if existing_user:
            if existing_user.username == username: raise HTTPException(409, "Bu kullanıcı adı alınmış!")
            else: raise HTTPException(409, "Bu E-posta kayıtlı!")

    code = str(random.randint(100000, 999999))
    set_verification_code(email, code)
    print(f"Kod: {code}") 
    
    if not send_email_notification(email, "Fingo Drive Kodun", f"Merhaba,\nKodun: {code}"):
        raise HTTPException(500, "Doğrulama kodu e-postanıza gönderilemedi. Lütfen bağlantınızı ve e-posta ayarlarınızı kontrol edin.")
    return {"mesaj": "Kod gönderildi!"}

@app.post("/api/verify_and_register")
def verify_and_register(data: dict, session: Session = Depends(get_session)):
    username = data.get("username")
    email = data.get("email")
    password = data.get("password")
    code = data.get("code")
    
    if not all([username, email, password, code]): raise HTTPException(400, "Eksik bilgi")
    if len(password) < 6: raise HTTPException(400, "Şifre en az 6 karakter olmalı")
    
    if not verify_code(email, code):
        raise HTTPException(400, "Doğrulama kodu hatalı veya süresi dolmuş")
    
    if session.exec(select(User).where((User.username == username) | (User.email == email))).first():
        raise HTTPException(409, "Kullanıcı zaten var")
    
    session.add(User(username=username, email=email, password=hash_password(password)))
    session.commit()
    
    path = utils.kullanici_yolu_getir(username)
    os.makedirs(path, exist_ok=True)
    verification_codes.pop(email, None)
    
    send_email_notification(email, "Hoş Geldin!", f"Merhaba {username}, hesabın açıldı.")
    return {"mesaj": "Kayıt Başarılı!"}

@app.post("/api/login")
def login(data: dict, session: Session = Depends(get_session)):
    email = data.get("email")
    password = data.get("password")
    user = session.exec(select(User).where(User.email == email)).first()
    if user and verify_password(user.password, password):
        # Otomatik şifre hash yükseltmesi (eğer eski düz metin şifreyse)
        if "$" not in user.password:
            user.password = hash_password(password)
            session.add(user)
            session.commit()
        return {"mesaj": "Giriş Başarılı", "token": f"token-{user.username}", "username": user.username, "email": user.email}
    raise HTTPException(401, "Hatalı e-posta veya şifre")

# ---------------------------------------------------------
# 6. PROFİL GÜNCELLEME İŞLEMLERİ
# ---------------------------------------------------------
@app.post("/api/update_profile")
def update_profile(data: dict, session: Session = Depends(get_session)):
    old_username = data.get("old_username")
    target_update = data.get("target") 
    new_value = data.get("new_value")

    user = session.exec(select(User).where(User.username == old_username)).first()
    if not user: raise HTTPException(404, "Kullanıcı yok")

    notify_email = user.email
    
    if target_update == "username":
        if not new_value or len(str(new_value).strip()) < 3:
            raise HTTPException(400, "Kullanıcı adı en az 3 karakter olmalı")
        clean_new_username = utils.dosya_ismini_temizle(str(new_value).strip())
        existing = session.exec(select(User).where(User.username == clean_new_username)).first()
        if existing and existing.id != user.id:
            raise HTTPException(409, "Bu kullanıcı adı zaten kullanımda")

        old_path = utils.kullanici_yolu_getir(old_username)
        new_path = utils.kullanici_yolu_getir(clean_new_username)
        if os.path.exists(old_path): os.rename(old_path, new_path)

        # Klasör meta verilerindeki kullanıcı adı anahtarlarını güncelle
        old_key_prefix = f"{old_username}/"
        user_metas = session.exec(select(FolderMetadata).where(
            (FolderMetadata.path_key == old_username) |
            (FolderMetadata.path_key.startswith(old_key_prefix))
        )).all()
        for m in user_metas:
            if m.path_key == old_username:
                m.path_key = clean_new_username
            else:
                m.path_key = m.path_key.replace(old_key_prefix, f"{clean_new_username}/", 1)
            session.add(m)

        user.username = clean_new_username
    elif target_update == "email":
        if not is_valid_email(new_value): raise HTTPException(400, "Geçersiz E-posta")
        send_email_notification(new_value, "E-Posta Değişti", "Yeni e-posta adresin bu.")
        user.email = new_value
    elif target_update == "password":
        if len(new_value) < 6: raise HTTPException(400, "Şifre en az 6 karakter olmalı")
        user.password = hash_password(new_value)
    
    session.add(user)
    session.commit()
    send_email_notification(notify_email, "Hesap Güncellemesi", f"{target_update} bilgisi güncellendi.")
    return {"mesaj": "Güncellendi", "username": user.username, "email": user.email}

@app.post("/api/request_account_deletion")
def request_account_deletion(data: dict, session: Session = Depends(get_session)):
    username = data.get("username")
    user = session.exec(select(User).where(User.username == username)).first()
    if not user: raise HTTPException(404, "Kullanıcı yok")
    
    code = str(random.randint(100000, 999999))
    set_verification_code(f"delete_{username}", code)
    print(f"Silme Kodu: {code}")
    
    if not send_email_notification(user.email, "HESAP SİLME", f"Kodun: {code}"):
        raise HTTPException(500, "Silme kodu e-postanıza gönderilemedi.")
    return {"mesaj": "Kod gönderildi."}

@app.delete("/api/confirm_account_deletion/{username}/{code}")
def confirm_account_deletion(username: str, code: str, session: Session = Depends(get_session)):
    key = f"delete_{username}"
    if not verify_code(key, code):
        raise HTTPException(400, "Kod hatalı veya süresi dolmuş")
    
    user = session.exec(select(User).where(User.username == username)).first()
    if not user: raise HTTPException(404, "Kullanıcı yok")
    
    user_email = user.email
    user_path = utils.kullanici_yolu_getir(username)
    if os.path.exists(user_path): shutil.rmtree(user_path)
    
    # Kullanıcının tüm klasör meta verilerini veritabanından temizle
    folder_metas = session.exec(select(FolderMetadata).where(
        (FolderMetadata.path_key == username) |
        (FolderMetadata.path_key.startswith(f"{username}/"))
    )).all()
    for fm in folder_metas:
        session.delete(fm)

    session.delete(user)
    session.commit()
    verification_codes.pop(key, None)

    # Kullanıcıya hesabın başarıyla silindiğine dair e-posta gönder
    if user_email:
        send_email_notification(
            user_email,
            "Fingo Drive - Hesabınız Başarıyla Silindi",
            f"Merhaba {username},\n\nFingo Drive hesabınız ve hesabınıza ait tüm dosyalar talebiniz doğrultusunda kalıcı olarak başarıyla silinmiştir.\n\nBizi tercih ettiğiniz için teşekkür ederiz.\n\nFingo Drive Ekibi"
        )

    return {"mesaj": "Hesap silindi"}

# ---------------------------------------------------------
# 7. DOSYA YÖNETİMİ (LİSTELEME, YÜKLEME, SİLME)
# ---------------------------------------------------------
@app.get("/api/files")
def list_files(username: str, path: str = "", session: Session = Depends(get_session)):
    target_folder = utils.kullanici_yolu_getir(username, path)
    root_folder = utils.kullanici_yolu_getir(username)
    toplam_boyut = utils.get_folder_size(root_folder)
    limit_byte = 1073741824 
    
    dosya_listesi = []
    if not os.path.exists(target_folder):
        os.makedirs(target_folder, exist_ok=True)
    
    for f in os.listdir(target_folder):
        full_path = os.path.join(target_folder, f)
        is_dir = os.path.isdir(full_path)
        if is_dir:
            folder_key = utils.normalize_folder_key(username, path, f)
            meta = session.exec(select(FolderMetadata).where(FolderMetadata.path_key == folder_key)).first()
            zaman = meta.created_at if meta else os.path.getctime(full_path)
            boyut = utils.get_folder_size(full_path)
        else:
            zaman = os.path.getmtime(full_path)
            boyut = os.path.getsize(full_path)
            
        dosya_listesi.append({
            'isim': f, 'boyut': boyut, 'boyut_str': utils.dosya_boyutu_formatla(boyut), 
            'tur': utils.dosya_turu_belirle(f, is_dir), 'tarih': utils.formatla_tarih_tr(zaman)
        })
    
    return {'dosyalar': dosya_listesi, 'kullanim': {'toplam_byte': toplam_boyut, 'toplam_str': utils.dosya_boyutu_formatla(toplam_boyut), 'limit_byte': limit_byte}}

@app.post("/api/upload")
def upload_file(file: UploadFile = File(...), username: str = Form(...), path: str = Form("")):
    user_folder = utils.kullanici_yolu_getir(username, path)
    root_folder = utils.kullanici_yolu_getir(username)
    current_size = utils.get_folder_size(root_folder)
    limit_byte = 1073741824  # 1 GB
    
    file.file.seek(0, 2)
    upload_size = file.file.tell()
    file.file.seek(0)
    
    if current_size + upload_size > limit_byte:
        raise HTTPException(400, "Depolama kotanız doldu! (1 GB)")

    os.makedirs(user_folder, exist_ok=True)
    clean_filename = utils.dosya_ismini_temizle(file.filename or "isimsiz_dosya")
    dosya_yolu = os.path.join(user_folder, clean_filename)
    base, ext = os.path.splitext(clean_filename)
    counter = 1
    while os.path.exists(dosya_yolu):
        dosya_yolu = os.path.join(user_folder, f"{base}_{counter}{ext}")
        counter += 1
    with open(dosya_yolu, "wb+") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"message": "Yüklendi", "mesaj": "Yüklendi"}

@app.post("/api/create_folder")
def create_folder(data: dict, session: Session = Depends(get_session)):
    raw_name = data.get("folder_name")
    if not raw_name or not str(raw_name).strip():
        raise HTTPException(400, "Klasör adı boş olamaz")
    clean_name = utils.dosya_ismini_temizle(str(raw_name))
    path_str = data.get("path", "") or ""
    target_path = utils.kullanici_yolu_getir(data.get("username"), os.path.join(path_str, clean_name))
    if os.path.exists(target_path):
        raise HTTPException(409, "Bu isimde bir klasör veya dosya zaten mevcut")
    os.makedirs(target_path, exist_ok=True)
    key = utils.normalize_folder_key(data.get('username'), path_str, clean_name)
    session.add(FolderMetadata(path_key=key, created_at=datetime.now().timestamp()))
    session.commit()
    return {"message": "Oluşturuldu", "mesaj": "Oluşturuldu"}

@app.post("/api/rename")
def rename_item(data: dict, session: Session = Depends(get_session)):
    username = data.get("username")
    path = data.get("path", "") or ""
    old_name = data.get("old_name")
    raw_new_name = data.get("new_name")
    if not raw_new_name or not str(raw_new_name).strip():
        raise HTTPException(400, "Yeni isim boş olamaz")
    new_name = utils.dosya_ismini_temizle(str(raw_new_name))
    
    base_path = utils.kullanici_yolu_getir(username, path)
    old_path = os.path.join(base_path, old_name)
    new_path = os.path.join(base_path, new_name)
    if not os.path.exists(old_path):
        raise HTTPException(404, "Bulunamadı")
    if os.path.exists(new_path):
        raise HTTPException(409, "Bu isimde bir dosya/klasör zaten mevcut")
    try:
        os.rename(old_path, new_path)
        if os.path.isdir(new_path):
            old_key = utils.normalize_folder_key(username, path, old_name)
            new_key = utils.normalize_folder_key(username, path, new_name)
            meta = session.exec(select(FolderMetadata).where(FolderMetadata.path_key == old_key)).first()
            if meta:
                meta.path_key = new_key
                session.add(meta)
            # Alt klasörlerin meta verilerini güncelle
            sub_metas = session.exec(select(FolderMetadata).where(FolderMetadata.path_key.startswith(f"{old_key}/"))).all()
            for sm in sub_metas:
                sm.path_key = sm.path_key.replace(f"{old_key}/", f"{new_key}/", 1)
                session.add(sm)
            session.commit()
        return {"message": "Değiştirildi", "mesaj": "Değiştirildi"}
    except Exception as e:
        raise HTTPException(500, str(e))

@app.delete("/api/delete/{username}/{filename:path}")
def delete_item(username: str, filename: str, session: Session = Depends(get_session)):
    clean_filename = filename.strip("/").strip("\\")
    if not clean_filename:
        raise HTTPException(400, "Kök dizin silinemez")
        
    target_path = utils.kullanici_yolu_getir(username, clean_filename)
    if not os.path.exists(target_path):
        raise HTTPException(404, "Bulunamadı")
    try:
        if os.path.isfile(target_path):
            os.remove(target_path)
        elif os.path.isdir(target_path):
            shutil.rmtree(target_path)
            folder_key = utils.normalize_folder_key(username, clean_filename)
            # Ana klasör ve tüm alt klasör meta verilerini sil
            metas_to_delete = session.exec(
                select(FolderMetadata).where(
                    (FolderMetadata.path_key == folder_key) | 
                    (FolderMetadata.path_key.startswith(f"{folder_key}/"))
                )
            ).all()
            for m in metas_to_delete:
                session.delete(m)
            session.commit()
    except Exception as e:
        raise HTTPException(500, str(e))
    return {"message": "Silindi", "mesaj": "Silindi"}

class FastFileResponse(FileResponse):
    chunk_size = 1024 * 1024  # 1 MB parça boyutu (videoların takılmadan akması ve hızlı yüklenmesi için)

@app.get("/api/file/{username}/{filename:path}")
def get_file(username: str, filename: str):
    file_path = utils.kullanici_yolu_getir(username, filename)
    
    if not os.path.exists(file_path) or not os.path.isfile(file_path):
        raise HTTPException(404, "Dosya bulunamadı")
    
    media_type, _ = mimetypes.guess_type(file_path)
    
    if media_type is None:
        ext = os.path.splitext(filename)[1].lower()
        if ext in (".m4a", ".m4b"): media_type = "audio/mp4"
        elif ext == ".mp4": media_type = "video/mp4"
        elif ext == ".webm": media_type = "video/webm"
        elif ext == ".mkv": media_type = "video/x-matroska"
        elif ext in (".jpg", ".jpeg"): media_type = "image/jpeg"
        elif ext == ".png": media_type = "image/png"
        elif ext == ".pdf": media_type = "application/pdf"
        else: media_type = "application/octet-stream"
        
    headers = {
        "Accept-Ranges": "bytes",
        "Cache-Control": "public, max-age=86400",
    }
    return FastFileResponse(
        file_path,
        media_type=media_type,
        filename=os.path.basename(file_path),
        content_disposition_type="inline",
        headers=headers,
    )

@app.post("/api/download_folder")
def download_folder_zip(data: dict):
    username = data.get("username")
    path = data.get("path", "") or ""
    folder_name = data.get("folder_name")
    if not folder_name:
        raise HTTPException(400, "Klasör adı belirtilmedi")
        
    base_path = utils.kullanici_yolu_getir(username, path)
    target_dir = os.path.join(base_path, folder_name)
    if not os.path.exists(target_dir) or not os.path.isdir(target_dir):
        raise HTTPException(404, "Bulunamadı")
        
    memory_file = io.BytesIO()
    with zipfile.ZipFile(memory_file, 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(target_dir):
            for file in files:
                file_path = os.path.join(root, file)
                zf.write(file_path, os.path.relpath(file_path, base_path))
    memory_file.seek(0)
    safe_filename = utils.dosya_ismini_temizle(folder_name)
    return StreamingResponse(
        memory_file,
        media_type="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{safe_filename}.zip"'}
    )

# ---------------------------------------------------------
# 8. E-POSTA VE ŞİFRE İŞLEMLERİ
# ---------------------------------------------------------
@app.post("/api/request_email_change")
def request_email_change(data: dict, session: Session = Depends(get_session)):
    username, new_email = data.get("username"), data.get("new_email")
    if not is_valid_email(new_email): raise HTTPException(400, "Geçersiz E-posta")
    if session.exec(select(User).where(User.email == new_email)).first(): raise HTTPException(409, "Kullanımda")
    code = str(random.randint(100000, 999999))
    set_verification_code(new_email, code)
    print(f"E-Posta Kod: {code}")
    if not send_email_notification(new_email, "E-Posta Onayı", f"Kodun: {code}"):
        raise HTTPException(500, "Onay kodu e-postanıza gönderilemedi.")
    return {"mesaj": "Kod gönderildi."}

@app.post("/api/confirm_email_change")
def confirm_email_change(data: dict, session: Session = Depends(get_session)):
    username, new_email, code = data.get("username"), data.get("new_email"), data.get("code")
    if not verify_code(new_email, code):
        raise HTTPException(400, "Hatalı veya süresi dolmuş kod")
    user = session.exec(select(User).where(User.username == username)).first()
    if not user: raise HTTPException(404, "Kullanıcı yok")
    user.email = new_email
    session.add(user); session.commit()
    verification_codes.pop(new_email, None)
    return {"mesaj": "Değiştirildi"}

@app.post("/api/request_password_reset")
def request_password_reset(data: dict, session: Session = Depends(get_session)):
    email = data.get("email")
    user = session.exec(select(User).where(User.email == email)).first()
    
    if not user:
        return {"mesaj": "Kod gönderildi."}

    code = str(random.randint(100000, 999999))
    set_verification_code(f"reset_{email}", code)
    print(f"Sıfırlama Kodu: {code}")

    if not send_email_notification(email, "Şifre Sıfırlama", f"Merhaba {user.username},\nŞifre sıfırlama kodun: {code}"):
        raise HTTPException(500, "Sıfırlama kodu e-postanıza gönderilemedi.")
    return {"mesaj": "Kod gönderildi."}

@app.post("/api/confirm_password_reset")
def confirm_password_reset(data: dict, session: Session = Depends(get_session)):
    email = data.get("email")
    code = data.get("code")
    new_password = data.get("new_password")

    key = f"reset_{email}"
    if not verify_code(key, code):
        raise HTTPException(400, "Hatalı Kod veya Süre Dolmuş")

    if len(new_password) < 6:
        raise HTTPException(400, "Şifre en az 6 karakter olmalı")

    user = session.exec(select(User).where(User.email == email)).first()
    if user:
        user.password = hash_password(new_password)
        session.add(user)
        session.commit()
        verification_codes.pop(key, None)
        return {"mesaj": "Şifren başarıyla değiştirildi!"}
    
    raise HTTPException(404, "Kullanıcı bulunamadı")