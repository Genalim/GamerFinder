from fastapi import FastAPI, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from contextlib import asynccontextmanager

from database import get_db, engine, Base
from models import User, UserLanguages, UserPlatforms, UserAvailability, UserAccounts, UserGames, Game, UserStyles
from schemas import UserCreate, LoginRequest, Token
from auth import get_password_hash, verify_password, create_access_token, get_current_user_id

from fastapi import File, UploadFile
import shutil
import os
from fastapi.staticfiles import StaticFiles

# 1. СПОЧАТКУ функція lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield

# 2. ПОТІМ створення app ОДИН РАЗ
app = FastAPI(title="GamerFinder API", lifespan=lifespan)

#Це для аватарок клієнта.
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# 3. ТЕПЕР всі ендпоінти ПІСЛЯ створення app
@app.post("/register")
async def register_user(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    # 1. Хешуємо пароль
    hashed_password = get_password_hash(user_data.password)

    # 2. Створюємо об'єкт користувача
    new_user = User(
        nickname=user_data.nickname,
        email=user_data.email,
        password=hashed_password,
        avatar=user_data.avatar,
        timezone_offset=user_data.timezone_offset,
        voice_chat=user_data.voice_chat,
        is_online=user_data.is_online,
        is_pro=user_data.is_pro
    )
    db.add(new_user)

    # Виконуємо flush, щоб отримати ID користувача (new_user.id) для подальших зв'язків
    await db.flush()

    # 3. Додаємо всі пов'язані дані

    # Мови
    for lang in user_data.languages:
        db.add(UserLanguages(user_id=new_user.id, lang=lang))

    # Платформи
    for plat in user_data.platforms:
        db.add(UserPlatforms(user_id=new_user.id, platform=plat))

    # Час доступності
    for hour in user_data.times:
        db.add(UserAvailability(user_id=new_user.id, utc_hour=hour))

    # Ігри (тепер приймаємо список ID)
    for game_id in user_data.games:
        db.add(UserGames(user_id=new_user.id, game_id=game_id))

    # Зв'язані акаунти
    for service, username in user_data.connected_accounts.items():
        db.add(UserAccounts(user_id=new_user.id, service=service, username=username))

    # Додаємо стилі гри
    for style in user_data.play_styles:
        db.add(UserStyles(user_id=new_user.id, style=style))

    # Додаємо час (використовуємо твій готовий метод з менеджера)
    for hour in user_data.times:
        db.add(UserAvailability(user_id=new_user.id, utc_hour=hour))

    # Фіксуємо зміни в базі
    await db.commit()

    return {"status": "success", "user_id": new_user.id}

@app.get("/users/{user_id}")
async def get_user_profile(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).options(selectinload(User.languages), selectinload(User.platforms), selectinload(User.availability), selectinload(User.accounts)).filter(User.id == user_id))
    user = result.scalars().first()
    if not user: raise HTTPException(status_code=404, detail="Користувача не знайдено")
    return user

@app.post("/login", response_model=Token)
async def login(login_data: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).filter(User.nickname == login_data.nickname))
    user = result.scalars().first()
    if not user or not verify_password(login_data.password, user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Невірний нікнейм або пароль")
    access_token = create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/my-profile")
async def get_my_profile(token: str = Header(...), db: AsyncSession = Depends(get_db)):
    # 1. Отримуємо ID користувача з токена
    user_id = get_current_user_id(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Невірний або прострочений токен")

    # 2. Робимо запит до БД
    result = await db.execute(
        select(User).options(
            selectinload(User.languages),
            selectinload(User.platforms),
            selectinload(User.availability),
            selectinload(User.accounts)
        ).filter(User.id == user_id)
    )
    user = result.scalars().first()

    if not user:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")

    return user

@app.get("/check-nickname/{nickname}")
async def check_nickname(nickname: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).filter(User.nickname == nickname))
    if result.scalars().first():
        return {"exists": True}
    return {"exists": False}

@app.post("/ensure-game")
async def ensure_game(game_data: dict, db: AsyncSession = Depends(get_db)):
    # Шукаємо гру за назвою
    result = await db.execute(select(Game).filter(Game.name == game_data['name']))
    game = result.scalars().first()

    if not game:
        game = Game(
            name=game_data['name'],
            image_url=game_data['image_url'],
            genres=game_data['genres']
        )
        db.add(game)
        await db.commit()
        await db.refresh(game)

    return {"game_id": game.id}

@app.post("/upload-avatar")
async def upload_avatar(file: UploadFile = File(...)):
    # Створюємо унікальне ім'я файлу (щоб не було колізій)
    file_location = f"uploads/avatars/{file.filename}"

    # Зберігаємо файл
    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Повертаємо шлях, за яким фото буде доступне
    return {"url": f"http://127.0.0.1:8000/{file_location}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)