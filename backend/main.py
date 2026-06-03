from fastapi import FastAPI, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession as Session
from contextlib import asynccontextmanager

from database import get_db, engine, Base
from models import User, UserLanguages, UserPlatforms, UserAvailability, UserAccounts, UserGames, Game, UserStyles
from schemas import UserCreate, LoginRequest, Token
from auth import get_password_hash, verify_password, create_access_token, get_current_user_id

from fastapi import File, UploadFile
import shutil
import os
from fastapi.staticfiles import StaticFiles
from fastapi.exceptions import RequestValidationError
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi import Depends



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


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    print(f"!!! ПОМИЛКА ВАЛІДАЦІЇ: {exc.errors()}")  # Це виведе деталі в консоль!
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors()},
    )

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
        # 1. Перевіряємо, чи існує гра з ТАКИМ ID
        result = await db.execute(select(Game).filter(Game.id == game_id))
        game = result.scalar_one_or_none()

        # 2. Якщо гри немає, ми створюємо її "на льоту"
        # (або можна додати запит до IGDB, якщо потрібні деталі)
        if not game:
            new_game = Game(
                id=game_id,
                name="Unknown Game", # Можна передавати назву з фронту, якщо хочеш
                image_url="",
                genres=[]
            )
            db.add(new_game)
            await db.flush() # Тепер ID існує в базі

        # 3. Додаємо зв'язок
        db.add(UserGames(user_id=new_user.id, game_id=game_id, style="default"))

    # Зв'язані акаунти
    for service, username in user_data.connected_accounts.items():
        db.add(UserAccounts(user_id=new_user.id, service=service, username=username))

    # Додаємо стилі гри
    for style in user_data.play_styles:
        db.add(UserStyles(user_id=new_user.id, style=style))


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
async def ensure_game(data: dict, db: AsyncSession = Depends(get_db)):
    igdb_id = data.get("igdb_id")
    name = data.get("name")
    image_url = data.get("image_url")
    genres = data.get("genres")

    # 1. Замість db.query(...) використовуємо select(...)
    result = await db.execute(select(Game).filter(Game.igdb_id == igdb_id))
    existing_game = result.scalars().first()

    if existing_game:
        return {"id": existing_game.id}
    else:
        # 2. Створюємо об'єкт
        new_game = Game(
            igdb_id=igdb_id,
            name=name,
            image_url=image_url,
            genres=str(genres)
        )
        db.add(new_game)
        # 3. Асинхронний commit
        await db.commit()
        await db.refresh(new_game)
        return {"id": new_game.id}

@app.post("/upload-avatar")
async def upload_avatar(file: UploadFile = File(...)):
    # Створюємо унікальне ім'я файлу (щоб не було колізій)
    file_location = f"uploads/avatars/{file.filename}"

    # Зберігаємо файл
    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Повертаємо шлях, за яким фото буде доступне
    return {"url": f"http://127.0.0.1:8000/{file_location}"}

@app.get("/games")
async def get_games(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Game))
    games = result.scalars().all()
    return [{"id": g.id, "name": g.name, "image_url": g.image_url, "genres": g.genres} for g in games]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)