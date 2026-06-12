from pydantic import BaseModel, EmailStr
from typing import List, Dict, Optional
import json
from pydantic import field_validator

# --- Схеми для вкладених об'єктів (щоб Pydantic розумів структури) ---

class GameResponse(BaseModel):
    id: int
    name: str
    image_url: Optional[str] = None
    genres: Optional[List[str]] = []

    @field_validator('genres', mode='before')
    @classmethod
    def parse_genres_string(cls, v):
        # Якщо приходить рядок типу "['Shooter']", перетворюємо його на список
        if isinstance(v, str):
            try:
                # Замінюємо одинарні лапки на подвійні для валідного JSON
                return json.loads(v.replace("'", '"'))
            except:
                return []
        return v or []

    class Config:
        from_attributes = True

class UserGameResponse(BaseModel):
    game_id: int
    game: GameResponse
    style: Optional[str] = None

    class Config:
        from_attributes = True

class LanguageResponse(BaseModel):
    lang: str

    class Config:
        from_attributes = True

class PlatformResponse(BaseModel):
    platform: str

    class Config:
        from_attributes = True

class AccountResponse(BaseModel):
    service: str
    username: str

    class Config:
        from_attributes = True

class AvailabilityResponse(BaseModel):
    utc_hour: int

    class Config:
        from_attributes = True

class StyleResponse(BaseModel):
    style: str

    class Config:
        from_attributes = True

# --- Основні схеми запитів ---

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
    id: int
    nickname: str

# --- Основна схема профілю ---

class UserProfileResponse(BaseModel):
    id: int
    nickname: str
    email: EmailStr
    avatar: Optional[str] = None
    is_pro: bool
    is_online: bool
    rating: int
    voice_chat: bool

    # Вкладені дані з використанням створених вище схем
    games: List[UserGameResponse] = []
    languages: List[LanguageResponse] = []
    platforms: List[PlatformResponse] = []
    accounts: List[AccountResponse] = []
    availability: List[AvailabilityResponse] = []
    styles: List[StyleResponse] = []

    class Config:
        from_attributes = True

class FriendshipResponse(BaseModel):
    id: int
    user_id: int
    friend_id: int
    status: str
    user: Optional[UserProfileResponse] = None # Додаємо це поле!

    class Config:
        from_attributes = True

class FriendRequestCreate(BaseModel):
    friend_id: int

class BlockedUserResponse(BaseModel):
    id: int
    nickname: str
    avatar: Optional[str] = None

    class Config:
        orm_mode = True

from pydantic import BaseModel, Field

class RateUserRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5, description="Rate from 1 to 5")

class PlaystylePreferenceRequest(BaseModel):
    styles: List[str]
    times: List[int]
    voice_chat: bool