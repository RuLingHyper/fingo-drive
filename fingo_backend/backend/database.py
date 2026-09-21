import os
from sqlmodel import SQLModel, Session, create_engine

# ---------------------------------------------------------
# 2. DOSYA AYARLARI
# ---------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SQLITE_FILE_NAME = os.path.join(BASE_DIR, "fingo.db")
SQLITE_URL = f"sqlite:///{SQLITE_FILE_NAME}"

# ---------------------------------------------------------
# 3. BAĞLANTI AYARLARI (Kritik Nokta)
# ---------------------------------------------------------
connect_args = {"check_same_thread": False}

# ---------------------------------------------------------
# 4. MOTORU ÇALIŞTIRMA (Engine)
# ---------------------------------------------------------
engine = create_engine(SQLITE_URL, connect_args=connect_args)

# ---------------------------------------------------------
# 5. TABLOLARI OLUŞTURMA
# ---------------------------------------------------------
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

# ---------------------------------------------------------
# 6. OTURUM YÖNETİMİ (Session)
# ---------------------------------------------------------
def get_session():
    with Session(engine) as session:
        yield session