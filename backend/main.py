from datetime import timedelta, datetime

from fastapi import FastAPI, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete, update, or_, func, desc, case
from sqlalchemy.orm import selectinload
from contextlib import asynccontextmanager
from typing import List, Optional
from fastapi import Query


from database import get_db, engine, Base
from models import User, UserLanguages, UserPlatforms, UserAvailability, UserAccounts, UserGames, Game, UserStyles, Friendship, UserRating, Notification, RatingRequest
from auth import get_password_hash, verify_password, create_access_token, get_current_user_id

from fastapi import File, UploadFile
import shutil
import os
from fastapi.staticfiles import StaticFiles
from fastapi.exceptions import RequestValidationError
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi import Depends
import uuid

from schemas import (
    UserCreate,
    LoginRequest,
    Token,
    UserProfileResponse,
    FriendRequestCreate,
    FriendshipResponse,
    BlockedUserResponse,
    RateUserRequest,
    PlaystylePreferenceRequest,
    NotificationCreate,
    NotificationResponse
)
#Function for changing pending to expired.
async def update_expired_notifications(db: AsyncSession):
    ten_minutes_ago = datetime.utcnow() - timedelta(minutes=10)

    # Оновлюємо статус
    await db.execute(
        update(Notification)
        .where(
            Notification.state == "pending",
            Notification.created_at < ten_minutes_ago
        )
        .values(state="expired")
    )
    # Зберігаємо зміни
    await db.commit()

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

@app.get("/users/{user_id}/my-rating")
async def get_my_rating_for_user(
        user_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    print(f"DEBUG: Запит /users/{user_id}/my-rating від юзера {current_user_id}")
    result = await db.execute(
        select(UserRating.rating).filter(
            UserRating.rater_id == current_user_id,
            UserRating.rated_user_id == user_id
        )
    )
    rating = result.scalar() or 0
    return {"rating": rating, "is_rated": rating > 0}

@app.get("/users/{user_id}", response_model=UserProfileResponse) # <--- ВАЖЛИВО
async def get_user_profile(
        user_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    print(f"DEBUG: Запит /users/{user_id}/my-rating від юзера {current_user_id}")
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
        raise HTTPException(status_code=404, detail="User not found")

    personal_rating_res = await db.execute(
        select(UserRating.rating).filter(
            UserRating.rater_id == current_user_id, # Потрібно передати або отримати з токена
            UserRating.rated_user_id == user_id
        )
    )
    personal_rating = personal_rating_res.scalar() or 0

    return user

@app.post("/login", response_model=Token)
async def login(login_data: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).filter(User.nickname == login_data.nickname))
    user = result.scalars().first()
    if not user or not verify_password(login_data.password, user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Wrong nickname or password")
    access_token = create_access_token(data={"sub": str(user.id)})
    return {"access_token": access_token, "token_type": "bearer", "id": user.id, "nickname": user.nickname}

@app.get("/my-profile")
async def get_my_profile(token: str = Header(...), db: AsyncSession = Depends(get_db)):
    # 1. Отримуємо ID користувача з токена
    user_id = get_current_user_id(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Wrong or expired token")

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
        raise HTTPException(status_code=404, detail="User not found")

    return user

@app.get("/check-nickname/{nickname}")
async def check_nickname(nickname: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).filter(User.nickname == nickname))
    if result.scalars().first():
        return {"exists": True}
    return {"exists": False}

@app.get("/check-email/{email}")
async def check_email(email: str, db: AsyncSession = Depends(get_db)):
    # Шукаємо користувача з такою поштою
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()
    return {"exists": user is not None}

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
async def find_matches(
        current_user_id: int,
        excluded_ids: Optional[List[int]] = Query(None), # Параметр для "живого" рефрешу
        db: AsyncSession = Depends(get_db)
):
    # 1. Завантажуємо поточного юзера з його уподобаннями
    result = await db.execute(
        select(User).options(
            selectinload(User.languages),
            selectinload(User.platforms),
            selectinload(User.availability),
            selectinload(User.games)
        ).filter(User.id == current_user_id)
    )
    me = result.scalars().first()
    if not me:
        raise HTTPException(status_code=404, detail="User not found")

    my_game_ids = [g.game_id for g in me.games]
    my_langs = [l.lang for l in me.languages]
    my_platforms = [p.platform for p in me.platforms]
    my_times = [a.utc_hour for a in me.availability]

    # 2. Список тих, кого треба виключити (друзі + заблоковані + я сам + ті, кого вже бачили)
    # Збираємо ID друзів та заблокованих
    # А. Ті, з ким ви вже друзі або кого ви заблокували (або хто вас)
    excluded_subquery = select(
        case(
            (Friendship.user_id == current_user_id, Friendship.friend_id),
            else_=Friendship.user_id
        )
    ).filter(
        or_(Friendship.user_id == current_user_id, Friendship.friend_id == current_user_id),
        # Виключаємо всіх, з ким є зв'язок (друзі) або статус 'blocked'
        Friendship.status.in_(['accepted', 'blocked'])
    ).scalar_subquery()
    # Б. ВАЖЛИВО: Окремо перевіримо статус, якщо ви є "ініціатором" або "отримувачем" блокування
    # (Це для того, щоб виключити тих, хто вас заблокував)
    blocked_by_others_subquery = select(
        case(
            (Friendship.friend_id == current_user_id, Friendship.user_id),
            else_=Friendship.friend_id
        )
    ).filter(
        or_(Friendship.user_id == current_user_id, Friendship.friend_id == current_user_id),
        Friendship.status == 'blocked'
    ).scalar_subquery()

    # 3. Рахуємо бали (Match Score)
    # Робимо це як обчислювану колонку, що базується на підзапитах для кожної таблиці зв'язків
    match_score = (
            (select(func.count(UserGames.game_id)).filter(UserGames.user_id == User.id, UserGames.game_id.in_(my_game_ids)).scalar_subquery() * 100) +
            case((User.is_online == True, 60), else_=0) +
            case((User.voice_chat == True, 30), else_=0) +
            (select(func.count(UserLanguages.lang)).filter(UserLanguages.user_id == User.id, UserLanguages.lang.in_(my_langs)).scalar_subquery() * 20) +
            (select(func.count(UserPlatforms.platform)).filter(UserPlatforms.user_id == User.id, UserPlatforms.platform.in_(my_platforms)).scalar_subquery() * 20) +
            (select(func.count(UserAvailability.utc_hour)).filter(UserAvailability.user_id == User.id, UserAvailability.utc_hour.in_(my_times)).scalar_subquery() * 10)
    ).label("match_score")

    # 4. Формуємо динамічний список фільтрів
    filters = [
        User.id != current_user_id,
        User.is_active == True,
        ~User.id.in_(excluded_subquery),
        ~User.id.in_(blocked_by_others_subquery),
        User.id.in_(select(UserGames.user_id).filter(UserGames.game_id.in_(my_game_ids)))
    ]

    # Додаємо фільтр excluded_ids тільки якщо він прийшов не порожнім
    if excluded_ids:
        filters.append(~User.id.in_(excluded_ids))

    # 5. Основний запит з динамічними фільтрами
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
        .filter(*filters)  # Розпаковуємо наш список фільтрів
        .order_by(desc(match_score), func.random())
        .limit(20)
    )

    result = await db.execute(stmt)

    user_list = result.scalars().all()

    # --- ТУТ ДЕБАГ ---
    for u in user_list:
        print(f"DEBUG: Nickname={u.nickname}, DB Rating={u.rating}")

    # Повертаємо змінну
    return user_list
    return result.scalars().all()


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
@app.post("/friends/request", response_model=FriendshipResponse)
async def send_friend_request(
        request: FriendRequestCreate,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. ЖОРСТКА ПЕРЕВІРКА: чи існує вже будь-який зв'язок між цими гравцями?
    stmt = select(Friendship).filter(
        ((Friendship.user_id == current_user_id) & (Friendship.friend_id == request.friend_id)) |
        ((Friendship.user_id == request.friend_id) & (Friendship.friend_id == current_user_id))
    )
    result = await db.execute(stmt)
    if result.scalars().first():
        # Якщо запис є - ми просто повертаємо помилку або ігноруємо
        raise HTTPException(status_code=400, detail="Request already exists")

    # 2. Якщо запису немає — створюємо
    new_request = Friendship(user_id=current_user_id, friend_id=request.friend_id, status="pending")
    db.add(new_request)
    await db.commit()
    # 3. Витягуємо об'єкт з БД з повним підвантаженням усіх зв'язків користувача
    result = await db.execute(
        select(Friendship)
        .options(
            selectinload(Friendship.user).selectinload(User.languages),
            selectinload(Friendship.user).selectinload(User.platforms),
            selectinload(Friendship.user).selectinload(User.accounts),
            selectinload(Friendship.user).selectinload(User.availability),
            selectinload(Friendship.user).selectinload(User.styles),
            selectinload(Friendship.user).selectinload(User.games).selectinload(UserGames.game)
        )
        .filter(Friendship.id == new_request.id)
    )
    final_request = result.scalars().first()

    return final_request

@app.patch("/friends/accept/{friendship_id}")
async def accept_friend_request(
        friendship_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    result = await db.execute(select(Friendship).filter(Friendship.id == friendship_id, Friendship.friend_id == current_user_id))
    friendship = result.scalars().first()
    if not friendship:
        raise HTTPException(status_code=404, detail="Request not found")

    friendship.status = "accepted"
    await db.commit()
    return {"message": "Friendship accepted"}

@app.delete("/friends/decline/{friendship_id}")
async def decline_friend_request(
        friendship_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Шукаємо запис
    result = await db.execute(select(Friendship).filter(Friendship.id == friendship_id, Friendship.friend_id == current_user_id))
    friendship = result.scalars().first()
    if not friendship:
        raise HTTPException(status_code=404, detail="Request not found")

    # Видаляємо запис
    await db.delete(friendship)
    await db.commit()
    return {"message": "Request declined"}

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
        User.id != current_user_id,
        User.is_active == True
    ).distinct() # Distinct важливо, щоб не було дублів

    result = await db.execute(stmt)
    return result.scalars().all()

# Отримання списку ВХІДНИХ запитів (pending)
@app.get("/friends/requests", response_model=List[FriendshipResponse])
async def get_friend_requests(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Використовуємо .unique() перед виконанням запиту — це критично для selectinload
    stmt = (
        select(Friendship)
        .options(
            selectinload(Friendship.user)
            .selectinload(User.languages),
            selectinload(Friendship.user).selectinload(User.platforms),
            selectinload(Friendship.user).selectinload(User.accounts),
            selectinload(Friendship.user).selectinload(User.availability),
            selectinload(Friendship.user).selectinload(User.styles),
            selectinload(Friendship.user).selectinload(User.games)
            .selectinload(UserGames.game)
        )
        .filter(
            Friendship.friend_id == current_user_id,
            Friendship.status == 'pending',
            # Тут ми звертаємось до зв'язаного об'єкта user,
            # щоб перевірити активність того, хто надіслав запит
            Friendship.user.has(User.is_active == True)
        )
    )

    result = await db.execute(stmt)
    # .unique() видаляє дублікати об'єктів Friendship, які могли з'явитися через join
    requests = result.unique().scalars().all()
    return requests

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
    return {"message": "Removed"}

#Блокування друга.
@app.patch("/friends/block/{friend_id}")
async def block_friend(
        friend_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Видаляємо будь-які попередні записи дружби чи запитів між цими двома користувачами
    await db.execute(
        delete(Friendship).filter(
            ((Friendship.user_id == current_user_id) & (Friendship.friend_id == friend_id)) |
            ((Friendship.user_id == friend_id) & (Friendship.friend_id == current_user_id))
        )
    )

    # 2. Створюємо новий запис блокування, де ініціатор — ви
    new_block = Friendship(user_id=current_user_id, friend_id=friend_id, status="blocked")
    db.add(new_block)
    await db.commit()

    return {"message": "User is blocked"}

@app.patch("/friends/unblock/{friend_id}")
async def unblock_user(
        friend_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Шукаємо запис, де саме ви були ініціатором блокування
    result = await db.execute(
        select(Friendship).filter(
            (Friendship.user_id == current_user_id) &
            (Friendship.friend_id == friend_id) &
            (Friendship.status == "blocked")
        )
    )
    friendship = result.scalars().first()

    if not friendship:
        raise HTTPException(status_code=403, detail="Action is denied or no info about user")

    # Повертаємо статус "accepted" — це відновлює дружбу, але знімає блок
    friendship.status = "accepted"
    await db.commit()

    return {"message": "User is unnlocked", "status": "accepted"}

@app.get("/friends/blocked", response_model=List[BlockedUserResponse])
async def get_blocked_friends(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    stmt = select(User).join(
        Friendship, User.id == Friendship.friend_id
    ).filter(
        Friendship.user_id == current_user_id,
        Friendship.status == "blocked",
        User.is_active == True
    ).distinct()

    result = await db.execute(stmt)
    users = result.scalars().all()

    return users

@app.get("/friends/status/{friend_id}")
async def get_friend_status(
        friend_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Шукаємо запис між вами (незалежно від того, хто перший кинув запит)
    result = await db.execute(
        select(Friendship).filter(
            ((Friendship.user_id == current_user_id) & (Friendship.friend_id == friend_id)) |
            ((Friendship.user_id == friend_id) & (Friendship.friend_id == current_user_id))
        )
    )
    friendship = result.scalars().first()

    if not friendship:
        return {"status": "none"}

    # Якщо статус "blocked"
    if friendship.status == "blocked":
        if friendship.user_id == current_user_id:
            # Це ВАШ запис блокування (ви ініціатор)
            return {"status": "blocked_by_me"}
        else:
            # Це ВАС заблокували (ініціатор інший гравець)
            return {"status": "blocked_by_other"}

    if friendship.status == "pending":
        if friendship.user_id == current_user_id:
            # Ви ініціатор запиту -> Вихідний запит
            return {"status": "request_sent"}
        else:
            # Інший гравець ініціатор -> Вхідний запит
            return {"status": "request_received"}

    return {"status": friendship.status}

@app.post("/users/{user_id}/rate")
async def rate_user(
        user_id: int,
        data: RateUserRequest,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    if user_id == current_user_id:
        raise HTTPException(status_code=400, detail="Ви не можете оцінювати власний профіль")

    # 1. Перевіряємо, чи існує користувач, якого оцінюють
    result = await db.execute(select(User).filter(User.id == user_id))
    target_user = result.scalars().first()
    if not target_user:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")

    # 2. Шукаємо, чи залишав цей юзер оцінку раніше
    rating_stmt = select(UserRating).filter(
        UserRating.rater_id == current_user_id,
        UserRating.rated_user_id == user_id
    )
    existing_rating_res = await db.execute(rating_stmt)
    existing_rating = existing_rating_res.scalars().first()

    if existing_rating:
        # Оновлюємо існуючу оцінку
        existing_rating.rating = data.rating
    else:
        # Створюємо нову оцінку
        new_rating = UserRating(
            rater_id=current_user_id,
            rated_user_id=user_id,
            rating=data.rating
        )
        db.add(new_rating)

    await db.commit()

    # 3. Перераховуємо середній рейтинг для користувача
    avg_stmt = select(func.avg(UserRating.rating)).filter(UserRating.rated_user_id == user_id)
    avg_result = await db.execute(avg_stmt)
    avg_rating = avg_result.scalar() or 0

    # Оновлюємо поле rating в таблиці users (округлюємо до цілого числа)
    target_user.rating = round(float(avg_rating), 1)
    await db.commit()

    return {
        "status": "success",
        "message": "Rate successfully saved",
        "new_average_rating": target_user.rating
    }

@app.put("/users/{user_id}/languages")
async def update_user_languages(user_id: int, langs: List[str], db: AsyncSession = Depends(get_db)):
    # 1. Очищаємо старі мови для user_id
    await db.execute(delete(UserLanguages).where(UserLanguages.user_id == user_id))
    # 2. Додаємо нові
    for lang in langs:
        db.add(UserLanguages(user_id=user_id, lang=lang))
    await db.commit()
    return {"message": "Languages updated"}

@app.put("/users/{user_id}/platforms")
async def update_user_platforms(user_id: int, platforms: List[str], db: AsyncSession = Depends(get_db)):
    await db.execute(delete(UserPlatforms).where(UserPlatforms.user_id == user_id))
    for p in platforms:
        db.add(UserPlatforms(user_id=user_id, platform=p))
    await db.commit()
    return {"message": "Platforms updated"}

@app.put("/users/{user_id}/games")
async def update_user_games(user_id: int, game_ids: List[int], db: AsyncSession = Depends(get_db)):
    await db.execute(delete(UserGames).where(UserGames.user_id == user_id))
    for g_id in game_ids:
        # Приклад прив'язки гри (стиль за замовчуванням 'default')
        db.add(UserGames(user_id=user_id, game_id=g_id, style="default"))
    await db.commit()
    return {"message": "Games updated"}

@app.put("/users/{user_id}/playstyle-preferences")
async def update_user_playstyle(
        user_id: int,
        data: PlaystylePreferenceRequest,
        db: AsyncSession = Depends(get_db)
):
    # Шукаємо користувача
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")

    # Оновлюємо налаштування голосового чату
    user.voice_chat = data.voice_chat

    # Очищаємо та додаємо нові стилі гри (таблиця user_styles)
    await db.execute(delete(UserStyles).where(UserStyles.user_id == user_id))
    for style_name in data.styles:
        db.add(UserStyles(user_id=user_id, style=style_name))

    # Очищаємо та додаємо години доступності (таблиця user_availability)
    await db.execute(delete(UserAvailability).where(UserAvailability.user_id == user_id))
    for hour in data.times:
        db.add(UserAvailability(user_id=user_id, utc_hour=hour))

    await db.commit()
    return {"message": "Playstyle successfully updated"}


@app.put("/users/{user_id}")
async def update_user_profile(
        user_id: int,
        data: dict,
        db: AsyncSession = Depends(get_db)
):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Користувача не знайдено")

    # Оновлюємо базові поля
    if "nickname" in data:
        user.nickname = data["nickname"]
    if "email" in data:
        user.email = data["email"]

    if data.get("password"):
        user.password = get_password_hash(data["password"])

    if "avatar" in data:
        user.avatar = data["avatar"]

    # === ДОДАЄМО ОБРОБКУ ПЛАТФОРМ ===
    if "connected_accounts" in data:
        # 1. Видаляємо старі підключені платформи з бази
        await db.execute(delete(UserAccounts).where(UserAccounts.user_id == user_id))

        # 2. Записуємо нові платформи, які прийшли з _platformControllers
        for service, username in data["connected_accounts"].items():
            if username:
                db.add(UserAccounts(user_id=user_id, service=service, username=username))

    await db.commit()
    await db.refresh(user)

    return user

@app.delete("/users/me")
async def delete_my_account(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    user = await db.get(User, current_user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Просто позначаємо як неактивного
    user.is_active = False
    user.nickname = f"Deleted_{current_user_id}"
    user.email = f"deleted_{current_user_id}@stub.com"

    # Решту зв'язків (ігри, стилі) можна видалити або залишити
    # (якщо вони нам не заважають, то можна навіть не видаляти,
    # просто користувач перестане з'являтися в пошуку)

    await db.commit()
    return {"message": "Account successfully deleted"}

#Users that reted PRO list
@app.get("/users/{user_id}/evaluations")
async def get_user_evaluations(
        user_id: int,
        db: AsyncSession = Depends(get_db)
):
    # Використовуємо selectinload для завантаження даних про того, хто оцінив
    stmt = (
        select(UserRating)
        .options(selectinload(UserRating.rater))
        .filter(UserRating.rated_user_id == user_id)
    )

    result = await db.execute(stmt)
    evaluations = result.scalars().all()

    # Формуємо список для фронтенду
    response = []
    for eval in evaluations:
        response.append({
            "evaluator_id": eval.rater_id,
            "evaluator_nickname": eval.rater.nickname,
            "stars": eval.rating,
            "evaluator_avatar": eval.rater.avatar # Тут підтягнеться шлях до аватара з моделі User
        })

    return response

#Notifications for match
@app.post("/send-invite")
async def send_invite(
        data: NotificationCreate,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. ЗАХИСТ ВІД КЛІКЕРА (10 хвилин)
    ten_minutes_ago = datetime.utcnow() - timedelta(minutes=10)
    exists = await db.execute(
        select(Notification).filter(
            Notification.sender_id == current_user_id,
            Notification.recipient_id == data.recipient_id,
            Notification.created_at >= ten_minutes_ago,
            Notification.state == "pending"
        )
    )
    if exists.scalars().first():
        raise HTTPException(status_code=429, detail="Wait 10 minutes before sending another invite")

    # 2. ЛІМІТ 3 ІНВАЙТИ НА ДОБУ
    day_ago = datetime.utcnow() - timedelta(hours=24)
    result = await db.execute(
        select(func.count(Notification.id)).filter(
            Notification.sender_id == current_user_id,
            Notification.recipient_id == data.recipient_id,
            Notification.created_at >= day_ago
        )
    )
    count = result.scalar()

    if count >= 3:
        raise HTTPException(status_code=429, detail="Limit exceeded (3 invites per 24h)")
    # Явно перетворюємо current_user_id на int,
    # щоб бути впевненим, що SQLAlchemy передасть число в БД
    sender_id_int = int(current_user_id)

    new_notif = Notification(
        id=str(uuid.uuid4()),
        recipient_id=data.recipient_id,
        sender_id=sender_id_int,  # Використовуємо int тут!
        message=data.message,
        type="match",
        state="pending",
        game=data.game
    )
    db.add(new_notif)
    await db.commit()
    return {"status": "success"}

@app.post("/accept-invite/{invite_id}")
async def accept_invite(
        invite_id: str,
        db: AsyncSession = Depends(get_db)
):
    # Використовуємо асинхронний select
    result = await db.execute(select(Notification).filter(Notification.id == invite_id))
    notif = result.scalars().first()

    if notif:
        notif.state = "accepted"
        await db.commit()
        return {"status": "accepted"}
    raise HTTPException(status_code=404, detail="Not found")

@app.get("/notifications")
async def get_my_notifications(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Спершу оновлюємо старі інвайти
    await update_expired_notifications(db)

    # 2."Лінива" перевірка RatingRequests
    # Шукаємо всі запити, які вже "дозріли" (пройшла 1 година)
    threshold = datetime.utcnow() - timedelta(hours=1)

    stmt_reqs = select(RatingRequest).filter(
        or_(RatingRequest.sender_id == current_user_id, RatingRequest.receiver_id == current_user_id),
        RatingRequest.created_at < threshold,
        RatingRequest.is_notification_sent == False
    )
    pending_reqs = await db.execute(stmt_reqs)

    for req in pending_reqs.scalars():
        # Створюємо нотифікацію для обох сторін
        # Беремо нікнейм іншого користувача для повідомлення
        # (для спрощення тут можна зробити додатковий запит до БД або просто вказати "teammate")

        for user_id in [req.sender_id, req.receiver_id]:
            new_notif = Notification(
                id=str(uuid.uuid4()),
                recipient_id=user_id,
                sender_id=req.sender_id if user_id == req.receiver_id else req.receiver_id,
                message="Rate your last teammate",
                type="rating",
                state="pending",
                game="Match Rating"
            )
            db.add(new_notif)

        req.is_notification_sent = True

    await db.commit() # Зберігаємо нові нотифікації та статус запитів

    # 3. ТЕПЕР робимо вибірку всіх актуальних (включно з новими, які щойно створили)
    stmt = (
        select(Notification)
        .options(selectinload(Notification.sender), selectinload(Notification.recipient))
        .filter(
            or_(
                # Отримувач бачить тільки:
                # 1) Нові інвайти (pending)
                # 2) Прострочені інвайти (expired)
                # 3) Рейтинги (type == 'rating')
                (
                        (Notification.recipient_id == current_user_id) &
                        or_(
                            Notification.state.in_(["pending", "expired"]),
                            Notification.type == "rating"
                        )
                ),

                # Відправник бачить тільки:
                # 1) Результат свого інвайту (accepted/declined)
                # 2) Рейтинги (type == 'rating')
                (
                        (Notification.sender_id == current_user_id) &
                        or_(
                            Notification.state.in_(["accepted", "declined"])

                        )
                )
            ),
            Notification.is_archived == False
        )
    )
    result = await db.execute(stmt)
    notifications = result.scalars().all()

    # 4. Формуємо відповідь (ваш оригінальний код)
    response = []
    for notif in notifications:
        is_i_am_sender = (notif.sender_id == current_user_id)
        other_user = notif.recipient if is_i_am_sender else notif.sender

        response.append({
            "id": notif.id,
            "sender_id": notif.sender_id,
            "user_nickname": other_user.nickname if other_user else "Unknown",
            "is_sender_online": other_user.is_online if other_user else False,
            "is_sender_pro": other_user.is_pro if other_user else False,
            "sender_rating": float(other_user.rating) if other_user and other_user.rating else 0.0,
            "message": notif.message,
            "state": notif.state,
            "type": notif.type,
            "game": notif.game,
            "time": notif.created_at.isoformat() if notif.created_at else ""
        })

    return response

@app.delete("/notifications/{notification_id}")
async def delete_notification(
        notification_id: str,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Знаходимо нотифікацію (без умови recipient_id, щоб знайти її і як відправник)
    result = await db.execute(select(Notification).filter(Notification.id == notification_id))
    notif = result.scalars().first()

    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")

    # 2. Перевірка: чи належить вона нам (або ми sender, або recipient)
    if notif.recipient_id != current_user_id and notif.sender_id != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # 3. ЗАХИСТ: Дозволяємо видалення тільки якщо вона в історії (is_archived)
    # АБО якщо це expired інвайт
    if not notif.is_archived and notif.state != "expired":
        raise HTTPException(
            status_code=403,
            detail="Cannot delete active notification. Archive it first."
        )

    await db.delete(notif)
    await db.commit()
    return {"message": "Notification deleted"}


@app.patch("/notifications/{notification_id}/accept")
async def accept_notification(
        notification_id: str,
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Notification).filter(Notification.id == notification_id)
    )
    notif = result.scalars().first()

    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")

    # Просто змінюємо статус на 'accepted'
    notif.state = "accepted"

    # Додаємо запис, щоб через час надіслати нотифікацію про рейтинг
    new_rating_req = RatingRequest(
        sender_id=notif.sender_id,
        receiver_id=notif.recipient_id,
        game_id=1, # Тут треба брати реальний ID гри, якщо він є в Notif
        is_notification_sent=False,
        is_rated=False
    )
    db.add(new_rating_req)

    await db.commit()
    return {"status": "accepted"}

@app.patch("/notifications/{notification_id}/update-status")
async def update_notification_status(
        notification_id: str,
        new_status: str, # "accepted" або "declined"
        db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Notification).filter(Notification.id == notification_id))
    notif = result.scalars().first()
    if not notif:
        raise HTTPException(status_code=404, detail="Not found")

    notif.state = new_status
    await db.commit()
    return {"status": "success"}

@app.patch("/notifications/{id}/archive")
async def archive_notification(id: str, db: AsyncSession = Depends(get_db)):
    notif = await db.get(Notification, id)

    if not notif:
        raise HTTPException(status_code=404, detail="Not found")

    # ЗАБОРОНА: Не можна архівувати pending інвайти
    if notif.state == "pending":
        raise HTTPException(status_code=400, detail="Cannot archive pending invite")

    notif.is_archived = True
    await db.commit()
    return {"status": "ok"}

@app.patch("/notifications/archive-all")
async def archive_all_notifications(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Архівуємо все, де ми отримувач (крім pending)
    # АБО все, де ми відправник (accepted/declined)
    stmt = (
        update(Notification)
        .where(
            ((Notification.recipient_id == current_user_id) & (Notification.state != "pending")) |
            ((Notification.sender_id == current_user_id) & (Notification.state.in_(["accepted", "declined"])))
        )
        .values(is_archived=True)
    )
    await db.execute(stmt)
    await db.commit()
    return {"status": "ok"}

@app.delete("/notifications/history/clear") # Назва шляху тепер відповідає логіці
async def clear_history(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Видаляємо ВСЕ, що заархівував цей користувач
    await db.execute(
        delete(Notification).filter(
            Notification.is_archived == True,
            ((Notification.recipient_id == current_user_id) | (Notification.sender_id == current_user_id))
        )
    )
    await db.commit()
    return {"message": "History cleared"}


@app.get("/notifications/history")
async def get_notifications_history(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    stmt = (
        select(Notification)
        .options(selectinload(Notification.sender), selectinload(Notification.recipient))
        .filter(
            (Notification.recipient_id == current_user_id) | (Notification.sender_id == current_user_id),
            Notification.is_archived == True  # ТІЛЬКИ АРХІВНІ
        )
        .order_by(Notification.created_at.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()




if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)