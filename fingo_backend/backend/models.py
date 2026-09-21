# ---------------------------------------------------------
# 1. KÜTÜPHANELER
# ---------------------------------------------------------
from typing import Optional
from sqlmodel import SQLModel, Field

# ---------------------------------------------------------
# 2. TABLO: KULLANICILAR (User)
# ---------------------------------------------------------
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    email: str = Field(index=True, unique=True)
    password: str

# ---------------------------------------------------------
# 3. TABLO: KLASÖR BİLGİLERİ (FolderMetadata)
# ---------------------------------------------------------
class FolderMetadata(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    path_key: str = Field(index=True, unique=True)
    created_at: float