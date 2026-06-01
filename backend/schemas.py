from pydantic import BaseModel, EmailStr
from typing import List, Dict, Optional

class UserCreate(BaseModel):
    nickname: str
    email: EmailStr
    password: str
    avatar: Optional[str] = None
    games: List[int] = []
    platforms: List[str] = []
    play_styles: List[str] = []
    times: List[int] = []
    timezone_offset: int = 0
    voice_chat: bool = False
    languages: List[str] = []
    connected_accounts: Dict[str, str] = {}
    is_online: bool = False
    is_pro: bool = False

class LoginRequest(BaseModel):
    nickname: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str