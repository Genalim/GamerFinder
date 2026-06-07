from fastapi import FastAPI, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload
from contextlib import asynccontextmanager
from typing import List


from database import get_db, engine, Base
from models import User, UserLanguages, UserPlatforms, UserAvailability, UserAccounts, UserGames, Game, UserStyles, Friendship
from schemas import UserCreate, LoginRequest, Token, UserProfileResponse, FriendRequestCreate, FriendshipResponse
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

@app.get("/users/{user_id}", response_model=UserProfileResponse) # <--- ВАЖЛИВО
async def get_user_profile(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User).options(
            selectinload(User.languages),
            selectinload(User.platforms),
            selectinload(User.availability),
            selectinload(User.accounts),
            # Важливо: завантажуємо ігри та інформацію про самі ігри
            selectinload(User.games).joinedload(UserGames.game),
            selectinload(User.styles)
        ).filter(User.id == user_id)
    )
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")

    return user

@app.post("/login", response_model=Token)
async def login(login_data: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).filter(User.nickname == login_data.nickname))
    user = result.scalars().first()
    if not user or not verify_password(login_data.password, user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Невірний нікнейм або пароль")
    access_token = create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer", "id": user.id, "nickname": user.nickname}

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



@app.get("/find-matches", response_model=List[UserProfileResponse])
async def find_matches(current_user_id: int, db: AsyncSession = Depends(get_db)):
    # 1. Спочатку завантажуємо поточного користувача з його іграми
    result = await db.execute(
        select(User).options(selectinload(User.games)).filter(User.id == current_user_id)
    )
    me = result.scalars().first()
    if not me:
        raise HTTPException(status_code=404, detail="Юзер не знайдений")

    my_game_ids = [g.game_id for g in me.games]

    # 2. Шукаємо інших користувачів, які грають у ці ігри
    # Використовуємо distinct(), щоб не було дублікатів, якщо гравець грає в кілька наших ігор
    stmt = (
        select(User)
        .options(
            selectinload(User.languages),
            selectinload(User.platforms),
            selectinload(User.availability),
            selectinload(User.accounts),
            selectinload(User.games).joinedload(UserGames.game),
            selectinload(User.styles)
        )
        .join(UserGames)
        .filter(
            and_(
                UserGames.game_id.in_(my_game_ids),
                User.id != current_user_id
            )
        )
        .distinct()
    )

    matches = await db.execute(stmt)
    return matches.scalars().all()

#@app.post("/friends/request")
#async def send_friend_request(friend_id: int, db: AsyncSession = Depends(get_db), current_user_id: int = Depends(get_current_user_id)):
    new_request = Friendship(user_id=current_user_id, friend_id=friend_id, status="pending")
    db.add(new_request)
    await db.commit()
    return {"message": "Запит надіслано"}

# 1. Відправити запит
#@app.post("/friends/request/{friend_id}")
#async def send_friend_request(friend_id: int, db: AsyncSession = Depends(get_db), current_user_id: int = Depends(get_current_user_id)):
    new_request = Friendship(user_id=current_user_id, friend_id=friend_id, status="pending")
    db.add(new_request)
    await db.commit()
    return {"status": "pending"}

# 2. Отримати статус дружби з конкретним юзером
@app.get("/friends/status/{friend_id}")
async def get_friend_status(friend_id: int, db: AsyncSession = Depends(get_db), current_user_id: int = Depends(get_current_user_id)):
    result = await db.execute(
        select(Friendship).filter(
            ((Friendship.user_id == current_user_id) & (Friendship.friend_id == friend_id)) |
            ((Friendship.user_id == friend_id) & (Friendship.friend_id == current_user_id))
        )
    )
    friendship = result.scalars().first()
    if not friendship:
        return {"status": "none"}
    return {"status": friendship.status}

@app.post("/friends/request", response_model=FriendshipResponse)
async def send_friend_request(
        request: FriendRequestCreate,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Перевірка, чи не існує вже такий запит
    stmt = select(Friendship).filter(
        ((Friendship.user_id == current_user_id) & (Friendship.friend_id == request.friend_id)) |
        ((Friendship.user_id == request.friend_id) & (Friendship.friend_id == current_user_id))
    )
    result = await db.execute(stmt)
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Запит вже існує або ви вже друзі")

    new_request = Friendship(user_id=current_user_id, friend_id=request.friend_id, status="pending")
    db.add(new_request)
    await db.commit()
    await db.refresh(new_request)
    return new_request

@app.patch("/friends/accept/{friendship_id}")
async def accept_friend_request(
        friendship_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    result = await db.execute(select(Friendship).filter(Friendship.id == friendship_id, Friendship.friend_id == current_user_id))
    friendship = result.scalars().first()
    if not friendship:
        raise HTTPException(status_code=404, detail="Запит не знайдено")

    friendship.status = "accepted"
    await db.commit()
    return {"message": "Дружбу підтверджено"}

@app.get("/friends/list", response_model=List[UserProfileResponse])
async def get_my_friends(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Додаємо selectinload, щоб завантажити дані для UserProfileResponse
    stmt = select(User).options(
        selectinload(User.languages),
        selectinload(User.platforms),
        selectinload(User.availability),
        selectinload(User.accounts),
        selectinload(User.games).joinedload(UserGames.game),
        selectinload(User.styles)
    ).join(Friendship, (User.id == Friendship.user_id) | (User.id == Friendship.friend_id)).filter(
        ((Friendship.user_id == current_user_id) | (Friendship.friend_id == current_user_id)),
        Friendship.status == "accepted",
        User.id != current_user_id
    ).distinct() # Distinct важливо, щоб не було дублів

    result = await db.execute(stmt)
    return result.scalars().all()

# Отримання списку ВХІДНИХ запитів (pending)
@app.get("/friends/requests", response_model=List[FriendshipResponse])
async def get_friend_requests(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    stmt = select(Friendship).filter(Friendship.friend_id == current_user_id, Friendship.status == "pending")
    result = await db.execute(stmt)
    return result.scalars().all()

# Видалення друга або скасування запиту
@app.delete("/friends/remove/{friend_id}")
async def remove_friend(
        friend_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    stmt = select(Friendship).filter(
        ((Friendship.user_id == current_user_id) & (Friendship.friend_id == friend_id)) |
        ((Friendship.user_id == friend_id) & (Friendship.friend_id == current_user_id))
    )
    result = await db.execute(stmt)
    friendship = result.scalars().first()
    if friendship:
        await db.delete(friendship)
        await db.commit()
    return {"message": "Видалено"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)