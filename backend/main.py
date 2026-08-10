from datetime import timedelta, datetime

import socketio
from fastapi import FastAPI, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete, update, or_, func, desc, case, text
from sqlalchemy.orm import selectinload
from sqlalchemy.orm import Session
from contextlib import asynccontextmanager
from typing import List, Optional
from fastapi import Query, Body

from chat_socket import sio

from database import get_db, engine, Base
from models import User, UserLanguages, UserPlatforms, UserAvailability, UserAccounts, UserGames, Game, UserStyles, Friendship, UserRating, Notification, RatingRequest, Chat, ChatMember, Message, MessageReaction, ChatHidden
from auth import get_password_hash, verify_password, create_access_token, get_current_user_id

from fastapi import File, UploadFile, Form
import shutil
import os
from fastapi.staticfiles import StaticFiles
from fastapi.exceptions import RequestValidationError
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi import Depends
import uuid
from pydantic import BaseModel

import smtplib
from email.message import EmailMessage

from fastapi import APIRouter

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
    now = datetime.utcnow()

    # 1. Оновлюємо Match (інвайти): 10 хвилин
    await db.execute(
        update(Notification)
        .where(
            Notification.state == "pending",
            Notification.type == "match",  # Чітко для матчів
            Notification.created_at < (now - timedelta(minutes=10))
        )
        .values(state="expired")
    )

    # 2. Оновлюємо Rating: 3 дні (як ти хотів)
    await db.execute(
        update(Notification)
        .where(
            Notification.state == "pending",
            Notification.type == "rating",  # Чітко для рейтингів
            Notification.created_at < (now - timedelta(days=3))
        )
        .values(state="expired")
    )

    await db.commit()

def send_verification_email(to_email: str, token: str):
    # Беремо хост і порт із docker-compose (за замовчуванням mailpit:1025)
    smtp_host = os.getenv("SMTP_HOST", "localhost")
    smtp_port = int(os.getenv("SMTP_PORT", "1025"))

    # Посилання, куди юзер нібито клікає з листа (можеш направити на свій локальний апі)
    verification_link = f"http://localhost:8000/auth/verify?token={token}"

    msg = EmailMessage()
    msg['Subject'] = "Verify your email"
    msg['From'] = "noreply@gamebuddy.com"
    msg['To'] = to_email

    # Гарний HTML-шаблон у твойому стилі
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Verify your email</title>
        <style>
            body {{
                background-color: #0F0F13;
                margin: 0;
                padding: 0;
                font-family: 'Poppins', Arial, sans-serif;
                color: #FFFFFF;
            }}
            .container {{
                max-width: 600px;
                margin: 0 auto;
                padding: 40px 20px;
                background-color: #0F0F13;
                text-align: center;
            }}
            .subject-text {{
                font-weight: 500;
                font-size: 16px;
                line-height: 27px;
                color: #FFFFFF;
                margin-bottom: 30px;
            }}
            .logo-img {{
                width: 130px;
                height: auto;
                margin-bottom: 25px;
                filter: drop-shadow(0px 0px 6px rgba(0, 245, 160, 0.4));
            }}
            .text-content {{
                text-align: center;
                color: #FFFFFF;
                font-size: 16px;
                line-height: 27px;
                padding: 0 10px;
            }}
            .btn-container {{
                text-align: center;
                margin: 35px 0;
            }}
            .verify-btn {{
                display: inline-block;
                font-weight: 700;
                font-size: 20px;
                line-height: 27px;
                color: #00F5A0 !important;
                text-decoration: none;
                text-shadow: 0px 0px 4px rgba(0, 245, 160, 0.5);
            }}
            .footer-box {{
                margin-top: 40px;
                background: #181826;
                border-radius: 12px;
                padding: 20px;
                font-size: 14px;
                line-height: 27px;
                color: #6F6F80;
                text-align: center;
            }}
            .footer-box a {{
                color: #6F6F80;
                text-decoration: underline;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <!-- Subject of the letter -->
            <div class="subject-text">Subject of the letter: Verify your email</div>

            <!-- Логотип-монстрик -->
            <div>
                <img src="http://192.168.0.229:8000/uploads/email/email_logo.png" alt="GAME BUDDY" class="logo-img">
            </div>

            <!-- Основний блок тексту (тепер без сірого фону та рамки, по центру) -->
            <div class="text-content">
                <p style="margin-top: 0;">Hi,</p>
                <p>Thanks for joining <strong>GAME BUDDY</strong>.</p>
                <p>Please confirm your email address to activate your account and start connecting with other players.</p>
                
                <!-- Кнопка Verify email -->
                <div class="btn-container">
                    <a href="http://192.168.0.229:8000/auth/verify?token={token}" class="verify-btn">Verify email</a>
                </div>

                <p style="margin-bottom: 0;">If you didn’t create this account, you can safely ignore this email.</p>
                
                <p style="margin-top: 30px; margin-bottom: 0;">
                    Thanks for your time,<br>
                    The GAME BUDDY Team <span style="color: #00F5A0; filter: drop-shadow(0px 0px 4px rgba(0, 245, 160, 0.5));">❤</span>
                </p>
            </div>

            <!-- Футер залишається в акуратному блоці знизу -->
            <div class="footer-box">
                <p style="margin: 0;">
                    <a href="http://192.168.0.229:8000/privacy">Privacy Policy</a> • 
                    <a href="http://192.168.0.229:8000/support">Contact Support</a>
                </p>
                <p style="margin: 0;">© 2026 GAME BUDDY</p>
            </div>
        </div>
    </body>
    </html>
    """

    msg.set_content("Please verify your email by clicking the link.")
    msg.add_alternative(html_content, subtype='html')

    try:
        # Для Mailpit пароль і логін не потрібні, тому просто шлемо на порт 1025
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.send_message(msg)
        print(f"✅ [MAILPIT] Лист успішно надіслано на {to_email}")
    except Exception as e:
        print(f"❌ [MAILPIT] Помилка відправки листа: {e}")



# 1. СПОЧАТКУ функція lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


# 2. ПОТІМ створення app ОДИН РАЗ
app = FastAPI(title="GamerFinder API", lifespan=lifespan)

@app.on_event("startup")
async def startup_event():
    async with engine.begin() as conn:
        # Це команда, яка змушує SQLAlchemy перечитати реальну структуру з бази
        await conn.run_sync(Base.metadata.reflect)

#app = socketio.ASGIApp(sio, app)

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

    #Генеруємо токен на час реєстрації
    verification_token = str(uuid.uuid4())

    # 2. Створюємо об'єкт користувача
    new_user = User(
        nickname=user_data.nickname,
        email=user_data.email,
        password=hashed_password,
        avatar=user_data.avatar,
        timezone_offset=user_data.timezone_offset,
        voice_chat=user_data.voice_chat,
        is_online=user_data.is_online,
        is_pro=user_data.is_pro,
        is_verified=False,
        verification_token=verification_token,
        created_at=datetime.utcnow()
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

    # 🆕 Створюємо нотифікацію про доступність PRO-тріалу одразу при реєстрації
    if not new_user.is_pro and not new_user.pro_trial_used:
        trial_notif = Notification(
            id=str(uuid.uuid4()),
            recipient_id=new_user.id,
            sender_id=new_user.id,
            message="Try PRO for free for 7 days!",
            type="pro",
            state="pending",
            game="trial_available",
            created_at=datetime.utcnow()
        )
        db.add(trial_notif)

    # Фіксуємо зміни в базі
    await db.commit()

    # 🔥 3. ВІДПРАВЛЯЄМО ЛИСТ ОДРАЗУ ПІСЛЯ УСПІШНОЇ РЕЄСТРАЦІЇ
    send_verification_email(new_user.email, verification_token)

    return {"status": "success", "user_id": new_user.id}

@app.post("/auth/test-email")
async def test_email_endpoint(data: dict):
    email = data.get("email", "test@gamebuddy.com")
    # Генеруємо фейковий токен для перевірки
    fake_token = str(uuid.uuid4())

    # Викликаємо нашу функцію відправки
    send_verification_email(email, fake_token)

    return {"status": "success", "message": f"Test email sent to {email}. Check Mailpit at http://localhost:8025"}

from fastapi.responses import HTMLResponse

@app.get("/privacy", response_class=HTMLResponse)
async def privacy_policy():
    # Точний шлях до файлу згідно з твоїм скріншотом: uploads/email/privacy/privacy.html
    file_path = "uploads/email/privacy/privacy.html"
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Privacy Policy page not found")

@app.get("/auth/verify", response_class=HTMLResponse)
async def verify_email(token: str, db: AsyncSession = Depends(get_db)):
    # 1. Шукаємо юзера за токеном
    result = await db.execute(select(User).where(User.verification_token == token))
    user = result.scalars().first()

    if not user:
        return """
        <html><body style="background-color: #0F0F13; color: white; text-align: center; padding-top: 50px; font-family: sans-serif;">
            <h2>Invalid or expired verification link.</h2>
        </body></html>
        """, 400

    # 2. Перевіряємо, чи пройшло більше 24 годин
    if user.created_at < datetime.utcnow() - timedelta(hours=24):
        # Видаляємо прострочений мертвий акаунт зі всіма зв'язками
        uid = user.id
        await db.execute(delete(UserLanguages).where(UserLanguages.user_id == uid))
        await db.execute(delete(UserPlatforms).where(UserPlatforms.user_id == uid))
        await db.execute(delete(UserAvailability).where(UserAvailability.user_id == uid))
        await db.execute(delete(UserGames).where(UserGames.user_id == uid))
        await db.execute(delete(UserAccounts).where(UserAccounts.user_id == uid))
        await db.execute(delete(UserStyles).where(UserStyles.user_id == uid))
        await db.delete(user)
        await db.commit()

        return """
        <html><body style="background-color: #0F0F13; color: #FF3B5C; text-align: center; padding-top: 50px; font-family: sans-serif;">
            <h2>Verification link has expired (24h limit).</h2>
            <p style="color: #A3A3B5;">This account has been removed. Please register again in the app.</p>
        </body></html>
        """

    # 3. Якщо все ок — підтверджуємо пошту!
    user.is_verified = True
    user.verification_token = None # Очищаємо токен, щоб не використали повторно
    await db.commit()

    # Повертаємо красиву сторінку успіху у стилі твого додатку
    return """
    <html><body style="background-color: #0F0F13; color: white; text-align: center; padding-top: 50px; font-family: sans-serif;">
        <h2 style="color: #00F5A0;">Email verified successfully!</h2>
        <p style="color: #A3A3B5;">You can now return to the GAME BUDDY app and sign in.</p>
    </body></html>
    """


@app.post("/auth/cancel-registration")
async def cancel_registration(data: dict, db: AsyncSession = Depends(get_db)):
    email = data.get("email")
    if not email:
        return {"status": "error"}

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    # Видаляємо лише якщо акаунт досі НЕ верифікований
    if user and not user.is_verified:
        uid = user.id
        await db.execute(delete(UserLanguages).where(UserLanguages.user_id == uid))
        await db.execute(delete(UserPlatforms).where(UserPlatforms.user_id == uid))
        await db.execute(delete(UserAvailability).where(UserAvailability.user_id == uid))
        await db.execute(delete(UserGames).where(UserGames.user_id == uid))
        await db.execute(delete(UserAccounts).where(UserAccounts.user_id == uid))
        await db.execute(delete(UserStyles).where(UserStyles.user_id == uid))
        await db.delete(user)
        await db.commit()

    return {"status": "success"}

@app.get("/auth/check-verification-status")
async def check_verification_status(email: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    if not user:
        return {"is_verified": False}

    return {"is_verified": user.is_verified}

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

    # 🛡️ Перевірка чи верифікована пошта
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please verify your email address before signing in."
        )

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

    # --- ТЕСТОВА ЛОГІКА ПЕРЕВІРКИ ЕКСПІРАЦІЇ PRO (6 ГОДИН) ---
    if user.is_pro and user.pro_expiry_date:
        now = datetime.utcnow()
        if now >= user.pro_expiry_date:
            # Час вийшов повністю — знімаємо PRO
            user.is_pro = False

            existing_expired = await db.execute(
                select(Notification).filter(
                    Notification.recipient_id == user.id,
                    Notification.game == "expired",
                    Notification.is_archived == False
                )
            )
            if not existing_expired.scalars().first():
                expired_notif = Notification(
                    id=str(uuid.uuid4()),
                    recipient_id=user.id,
                    sender_id=user.id,
                    message="Your PRO subscription has ended.",
                    type="pro",
                    state="pending",
                    game="expired",
                    created_at=datetime.utcnow()
                )
                db.add(expired_notif)
            await db.commit()
        else:
            time_left = user.pro_expiry_date - now

            # 1) Перше нагадування: коли залишилось менше або рівно 2 години
            if time_left <= timedelta(hours=2) and time_left > timedelta(hours=1):
                existing_expiring = await db.execute(
                    select(Notification).filter(
                        Notification.recipient_id == user.id,
                        Notification.game == "expiring",
                        Notification.is_archived == False
                    )
                )
                if not existing_expiring.scalars().first():
                    expiring_notif = Notification(
                        id=str(uuid.uuid4()),
                        recipient_id=user.id,
                        sender_id=user.id,
                        message="Your PRO plan expires soon!",
                        type="pro",
                        state="pending",
                        game="expiring",
                        created_at=datetime.utcnow()
                    )
                    db.add(expiring_notif)
                    await db.commit()

            # 2) Друге нагадування: коли залишилось менше або рівно 1 година
            elif time_left <= timedelta(hours=1):
                existing_expiring_soon = await db.execute(
                    select(Notification).filter(
                        Notification.recipient_id == user.id,
                        Notification.game == "expiring",
                        Notification.is_archived == False
                    )
                )
                # Якщо хочеш розрізняти тексти для 2 годин і 1 години,
                # тут можна додати ще одну перевірку або оновити існуючу картку.

    # Оригінальна логіка тріалу (без змін)
    if not user.is_pro and not user.pro_trial_used:
        # 1. Перевіряємо, чи немає вже активної картки тріалу
        existing_trial = await db.execute(
            select(Notification).filter(
                Notification.recipient_id == user.id,
                Notification.game == "trial_available",
                Notification.is_archived == False
            )
        )

        if not existing_trial.scalars().first():
            # 2. Перевіряємо, чи пройшов час після того, як він її видалив (наприклад, 1 година)
            can_show_trial = True
            if user.pro_trial_dismissed_at:
                cooldown_period = timedelta(hours=1) # Час, через який тріал з'явиться знову
                if datetime.utcnow() < user.pro_trial_dismissed_at + cooldown_period:
                    can_show_trial = False

            if can_show_trial:
                trial_notif = Notification(
                    id=str(uuid.uuid4()),
                    recipient_id=user.id,
                    sender_id=user.id,
                    message="Try PRO for free for 7 days!",
                    type="pro",
                    state="pending",
                    game="trial_available",
                    created_at=datetime.utcnow()
                )
                db.add(trial_notif)
                await db.commit()

    return user

@app.get("/check-nickname/{nickname}")
async def check_nickname(nickname: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).filter(User.nickname == nickname))
    user = result.scalars().first()

    if user:
        # Якщо акаунт не верифікований і пройшло більше 24 годин — видаляємо його разом зі зв'язками
        if not user.is_verified and user.created_at < datetime.utcnow() - timedelta(hours=24):
            uid = user.id
            # Видаляємо всі дочірні зв'язки по черзі, щоб уникнути помилок БД
            await db.execute(delete(UserLanguages).where(UserLanguages.user_id == uid))
            await db.execute(delete(UserPlatforms).where(UserPlatforms.user_id == uid))
            await db.execute(delete(UserAvailability).where(UserAvailability.user_id == uid))
            await db.execute(delete(UserGames).where(UserGames.user_id == uid))
            await db.execute(delete(UserAccounts).where(UserAccounts.user_id == uid))
            await db.execute(delete(UserStyles).where(UserStyles.user_id == uid))

            # Сам юзер
            await db.delete(user)
            await db.commit()
            return {"exists": False} # Нікнейм знову вільний!

        return {"exists": True}

    return {"exists": False}


@app.get("/check-email/{email}")
async def check_email(email: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    if user:
        # Якщо акаунт не верифікований і пройшло більше 24 годин — видаляємо його разом зі зв'язками
        if not user.is_verified and user.created_at < datetime.utcnow() - timedelta(hours=24):
            uid = user.id
            # Видаляємо всі дочірні зв'язки по черзі
            await db.execute(delete(UserLanguages).where(UserLanguages.user_id == uid))
            await db.execute(delete(UserPlatforms).where(UserPlatforms.user_id == uid))
            await db.execute(delete(UserAvailability).where(UserAvailability.user_id == uid))
            await db.execute(delete(UserGames).where(UserGames.user_id == uid))
            await db.execute(delete(UserAccounts).where(UserAccounts.user_id == uid))
            await db.execute(delete(UserStyles).where(UserStyles.user_id == uid))

            # Сам юзер
            await db.delete(user)
            await db.commit()
            return {"exists": False} # Пошта знову вільна!

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
    os.makedirs("uploads/avatars", exist_ok=True)

    # Створюємо унікальне ім'я файлу (щоб не було колізій)
    file_location = f"uploads/avatars/{file.filename}"

    # Зберігаємо файл
    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # ЗМІНЮЄМО ТУТ: повертаємо лише відносний шлях зі слешем на початку
    return {"url": f"/{file_location}"}

@app.get("/avatars-list")
async def get_avatars_list():
    free_dir = "uploads/avatars/free"
    pro_dir = "uploads/avatars/pro"

    # Створюємо теки на всяк випадок, якщо їх немає
    os.makedirs(free_dir, exist_ok=True)
    os.makedirs(pro_dir, exist_ok=True)

    # Формуємо відносні шляхи, наприклад: /uploads/avatars/free/avatar_1.jpg
    free_paths = [f"/uploads/avatars/free/{f}" for f in os.listdir(free_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))]
    pro_paths = [f"/uploads/avatars/pro/{f}" for f in os.listdir(pro_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))]

    free_paths.sort()
    pro_paths.sort()

    return {"free": free_paths, "pro": pro_paths}

@app.get("/games")
async def get_games(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Game))
    games = result.scalars().all()
    return [{"id": g.id, "name": g.name, "image_url": g.image_url, "genres": g.genres} for g in games]

@app.get("/find-matches", response_model=List[UserProfileResponse])
async def find_matches(
        current_user_id: int,
        excluded_ids: Optional[List[int]] = Query(None),
        selected_game_id: Optional[int] = Query(None), # 🆕 Приймаємо ID обраної гри з фільтра
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

    # 2. Список тих, кого треба виключити
    excluded_subquery = select(
        case(
            (Friendship.user_id == current_user_id, Friendship.friend_id),
            else_=Friendship.user_id
        )
    ).filter(
        or_(Friendship.user_id == current_user_id, Friendship.friend_id == current_user_id),
        Friendship.status.in_(['accepted', 'blocked'])
    ).scalar_subquery()

    blocked_by_others_subquery = select(
        case(
            (Friendship.friend_id == current_user_id, Friendship.user_id),
            else_=Friendship.friend_id
        )
    ).filter(
        or_(Friendship.user_id == current_user_id, Friendship.friend_id == current_user_id),
        Friendship.status == 'blocked'
    ).scalar_subquery()

    # 3. Бали матчу
    match_score = (
            (select(func.count(UserGames.game_id)).filter(UserGames.user_id == User.id, UserGames.game_id.in_(my_game_ids)).scalar_subquery() * 100) +
            case((User.is_online == True, 60), else_=0) +
            case((User.voice_chat == True, 30), else_=0) +
            (select(func.count(UserLanguages.lang)).filter(UserLanguages.user_id == User.id, UserLanguages.lang.in_(my_langs)).scalar_subquery() * 20) +
            (select(func.count(UserPlatforms.platform)).filter(UserPlatforms.user_id == User.id, UserPlatforms.platform.in_(my_platforms)).scalar_subquery() * 20) +
            (select(func.count(UserAvailability.utc_hour)).filter(UserAvailability.user_id == User.id, UserAvailability.utc_hour.in_(my_times)).scalar_subquery() * 10)
    ).label("match_score")

    # 4. 🔥 ГОЛОВНА ЗМІНА ФІЛЬТРІВ:
    # Якщо користувач обрав конкретну гру у верхньому фільтрі — шукаємо ТІЛЬКИ по ній!
    if selected_game_id:
        target_game_ids = [selected_game_id]
    else:
        target_game_ids = my_game_ids # За замовчуванням — усі мої ігри

    filters = [
        User.id != current_user_id,
        User.is_active == True,
        ~User.id.in_(excluded_subquery),
        ~User.id.in_(blocked_by_others_subquery),
        # Тепер перевіряємо наявність гри(ігор) з урахуванням вибору фільтра
        User.id.in_(select(UserGames.user_id).filter(UserGames.game_id.in_(target_game_ids)))
    ]

    if excluded_ids:
        filters.append(~User.id.in_(excluded_ids))

    # 5. Запит до бази
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
        .filter(*filters)
        .order_by(desc(match_score), func.random())
        .limit(20)
    )

    result = await db.execute(stmt)
    user_list = result.scalars().all()

    return user_list


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
@app.post("/send-invite", status_code=status.HTTP_201_CREATED)
async def send_invite(
        data: NotificationCreate,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Захист 10 хвилин
    ten_minutes_ago = datetime.utcnow() - timedelta(minutes=10)

    # Використовуй .scalar_one_or_none() для отримання одного результату
    query = select(Notification).filter(
        Notification.sender_id == current_user_id,
        Notification.recipient_id == data.recipient_id,
        Notification.created_at >= ten_minutes_ago,
        Notification.state == "pending",
        Notification.type == "match"
    )
    result = await db.execute(query)
    if result.scalars().first():
        raise HTTPException(
            status_code=429,
            detail="Wait 10 minutes before sending another invite"
        )

    # 2. Ліміт 3 інвайти на добу (тільки від мене до нього і тільки тип match)
    day_ago = datetime.utcnow() - timedelta(hours=24)
    count_query = select(func.count(Notification.id)).filter(
        Notification.sender_id == current_user_id,
        Notification.recipient_id == data.recipient_id,
        Notification.created_at >= day_ago,
        Notification.type == "match"
    )
    count_result = await db.execute(count_query)
    if (count_result.scalar() or 0) >= 3:
        raise HTTPException(
            status_code=429,
            detail="Limit exceeded (3 invites per 24h)"
        )

    # 3. Створення нотифікації
    new_notif = Notification(
        id=str(uuid.uuid4()),
        recipient_id=data.recipient_id,
        sender_id=int(current_user_id),
        message=data.message,
        type="match",
        state="pending",
        game=data.game,
        created_at=datetime.utcnow() # Краще явно встановити час, якщо модель не робить це сама
    )

    db.add(new_notif)
    await db.commit()

    # Отримуємо нікнейм відправника для гарного повідомлення
    sender = await db.get(User, current_user_id)

    await sio.emit('new_notification', {
        "id": new_notif.id,
        "user_nickname": sender.nickname,
        "message": new_notif.message,
        "type": new_notif.type,
        "state": new_notif.state,
        "game": new_notif.game,
        "sender_id": str(new_notif.sender_id),
        "time": new_notif.created_at.isoformat()
    }, room=str(data.recipient_id)) # room = ID отримувача
    # ----------------

    return {"status": "success", "message": "Invite sent successfully"}

@app.get("/notifications")
async def get_my_notifications(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Спершу оновлюємо старі інвайти
    await update_expired_notifications(db)

    # 2."Лінива" перевірка RatingRequests
    # Шукаємо всі запити, які вже "дозріли" (пройшла 1 година)
    threshold = datetime.utcnow() - timedelta(minutes=3)

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
            await db.flush()

            await sio.emit('new_notification', {
                "id": new_notif.id,
                "user_nickname": "Teammate", # або логіка отримання ніку
                "message": new_notif.message,
                "type": "rating",
                "state": "pending",
                "game": "Match Rating",
                "sender_id": str(req.sender_id if user_id == req.receiver_id else req.receiver_id),
                "time": datetime.utcnow().isoformat()
            }, room=str(user_id))

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
            "recipient_id": notif.recipient_id,
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
    # 1. Знаходимо нотифікацію
    result = await db.execute(select(Notification).filter(Notification.id == notification_id))
    notif = result.scalars().first()

    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")

    # 2. Перевірка: чи належить вона нам
    if notif.recipient_id != current_user_id and notif.sender_id != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # 3. ЗАХИСТ: Дозволяємо видалення якщо:
    # - вона в історії (is_archived)
    # - або це expired інвайт
    # - або це тип rating
    # - АБО це наша картка trial_available (яку можна видаляти хрестиком)
    if not notif.is_archived and notif.state != "expired" and notif.type != "rating" and notif.game != "trial_available":
        raise HTTPException(
            status_code=403,
            detail="Cannot delete active notification. Archive it first."
        )

    # 4. Якщо це тріал — оновлюємо час закриття для кулдауну
    if notif.game == "trial_available":
        user = await db.get(User, current_user_id)
        if user:
            user.pro_trial_dismissed_at = datetime.utcnow()

    await db.delete(notif)
    await db.commit()
    return {"message": "Notification deleted"}


@app.patch("/notifications/{notification_id}/accept")
async def accept_notification(
        notification_id: str,
        db: AsyncSession = Depends(get_db)
):
    # 1. Знаходимо нотифікацію
    result = await db.execute(select(Notification).filter(Notification.id == notification_id))
    notif = result.scalars().first()

    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")

    # 2. Змінюємо статус та додаємо запит на рейтинг
    notif.state = "accepted"
    new_rating_req = RatingRequest(
        sender_id=notif.sender_id,
        receiver_id=notif.recipient_id,
        game_id=1,
        is_notification_sent=False,
        is_rated=False
    )
    db.add(new_rating_req)

    # 3. Логіка отримання/створення чату
    stmt = text("""
        SELECT cm.chat_id 
        FROM chat_members cm
        JOIN chats c ON cm.chat_id = c.id
        WHERE c.is_group = FALSE AND cm.user_id IN (:u1, :u2)
        GROUP BY cm.chat_id
        HAVING COUNT(DISTINCT cm.user_id) = 2
    """)
    res = await db.execute(stmt, {"u1": notif.sender_id, "u2": notif.recipient_id})
    chat_id = res.scalar()

    if not chat_id:
        new_chat = Chat(is_group=False)
        db.add(new_chat)
        await db.flush()
        chat_id = new_chat.id
        db.add(ChatMember(chat_id=chat_id, user_id=notif.sender_id))
        db.add(ChatMember(chat_id=chat_id, user_id=notif.recipient_id))
        await db.flush()

    # 4. Додаємо автоматичне повідомлення
    auto_msg = Message(
        chat_id=chat_id,
        sender_id=notif.sender_id,
        content=f"Lets play {notif.game}!!!",
        status="sent"
    )
    db.add(auto_msg)

    await db.execute(
        update(ChatMember)
        .where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id != notif.sender_id
        )
        .values(unread_count=ChatMember.unread_count + 1)
    )

    await db.commit()

    # 🚀 ДОДАЄМО СОКЕТ-ПОВІДОМЛЕННЯ ДЛЯ ВІДПРАВНИКА ІНВАЙТУ (що його інвайт прийнято!)
    await sio.emit('new_notification', {
        "id": notif.id,
        "user_nickname": "Teammate", # Можна підтягти нік отримувача за потреби
        "message": notif.message,
        "type": notif.type,
        "state": "accepted",
        "game": notif.game,
        "sender_id": str(notif.recipient_id),
        "time": datetime.utcnow().isoformat()
    }, room=str(notif.sender_id))

    # 5. Емітимо подію через сокет, щоб чат відкрився і повідомлення з'явилося
    unread_res = await db.execute(
        select(ChatMember.unread_count).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == notif.recipient_id
        )
    )
    recipient_unread = unread_res.scalar() or 1

    await sio.emit('new_message', {
        'chat_id': str(chat_id),
        'content': auto_msg.content,
        'sender_id': notif.sender_id,
        'unread_count': recipient_unread
    }, room=str(chat_id))

    return {"status": "accepted", "chat_id": str(chat_id)}

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

    # 🚀 МИТТЄВИЙ СОКЕТ ДЛЯ ВІДПРАВНИКА (щоб він побачив статус "declined" або новий стан)
    await sio.emit('new_notification', {
        "id": notif.id,
        "message": notif.message,
        "type": notif.type,
        "state": notif.state,
        "game": notif.game,
        "sender_id": str(notif.recipient_id),
        "time": datetime.utcnow().isoformat()
    }, room=str(notif.sender_id))

    return {"status": "success"}

@app.patch("/notifications/{id}/archive")
async def archive_notification(id: str, db: AsyncSession = Depends(get_db)):
    notif = await db.get(Notification, id)

    if not notif:
        raise HTTPException(status_code=404, detail="Not found")

    # ЗАБОРОНА: Не можна архівувати pending інвайти
    if notif.state == "pending" and notif.type not in ["rating", "pro"]:
        raise HTTPException(status_code=400, detail="Cannot archive pending invite")

    notif.is_archived = True
    await db.commit()
    return {"status": "ok"}

@app.patch("/notifications/archive-all")
async def archive_all_notifications(
        notification_type: Optional[str] = None, # 'match', 'rating', 'pro', тощо
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Базова умова (твоя поточна логіка прав доступу)
    base_access_condition = or_(
        (Notification.recipient_id == current_user_id) &
        or_(Notification.state != "pending", Notification.type == "rating"),

        (Notification.sender_id == current_user_id) &
        (Notification.state.in_(["accepted", "declined"]))
    )

    # Додаткова умова для фільтрації по типу
    type_condition = True # Якщо None, ігноруємо фільтр
    if notification_type:
        type_condition = (Notification.type == notification_type)

    # Комбінуємо все разом для звичайного архівування,
    # але виключаємо trial_available з масового закидання в архів
    stmt = (
        update(Notification)
        .where(base_access_condition)
        .where(type_condition) # Додаємо фільтрацію типу
        .where(Notification.game != "trial_available") # <--- Тріал не архівуємо
        .values(is_archived=True)
    )

    await db.execute(stmt)

    # Якщо користувач робить archive-all на PRO або у загальному списку ('All' -> notification_type is None),
    # ми додатково видаляємо ТІЛЬКИ активну картку тріалу і запускаємо кулдаун (годинний таймер)
    if notification_type is None or notification_type == "pro":
        active_trial_res = await db.execute(
            select(Notification).filter(
                Notification.recipient_id == current_user_id,
                Notification.game == "trial_available",
                Notification.is_archived == False
            )
        )
        trial_notif = active_trial_res.scalars().first()

        if trial_notif:
            user = await db.get(User, current_user_id)
            if user:
                user.pro_trial_dismissed_at = datetime.utcnow()

            await db.delete(trial_notif)

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
            Notification.is_archived == True
        )
        .order_by(Notification.created_at.desc())
    )
    result = await db.execute(stmt)
    notifications = result.scalars().all()

    # Формуємо відповідь точно так само, як в активних нотифікаціях
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


class GetOrCreateChatRequest(BaseModel):
    recipient_id: int
#=====Chats=======#
@app.post("/chats/get-or-create")
async def get_or_create_chat(
        recipient_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Перевірка на блок
    stmt_block = select(Friendship).filter(
        or_(
            and_(Friendship.user_id == current_user_id, Friendship.friend_id == recipient_id, Friendship.status == 'blocked'),
            and_(Friendship.user_id == recipient_id, Friendship.friend_id == current_user_id, Friendship.status == 'blocked')
        )
    )
    is_blocked = await db.execute(stmt_block)
    if is_blocked.scalars().first():
        raise HTTPException(status_code=403, detail="Ви не можете спілкуватися з цим користувачем")

    # 2. Пошук існуючого чату
    stmt = text("""
        SELECT cm.chat_id 
        FROM chat_members cm
        JOIN chats c ON cm.chat_id = c.id
        WHERE c.is_group = FALSE AND cm.user_id IN (:u1, :u2)
        GROUP BY cm.chat_id
        HAVING COUNT(DISTINCT cm.user_id) = 2
    """)
    res = await db.execute(stmt, {"u1": current_user_id, "u2": recipient_id})
    chat_id = res.scalar()

    # Якщо чату немає — створюємо
    if not chat_id:
        print(f"DEBUG: Чату немає, створюємо новий приватний чат...")
        new_chat = Chat(is_group=False)
        db.add(new_chat)
        await db.flush()
        chat_id = new_chat.id
        db.add(ChatMember(chat_id=chat_id, user_id=current_user_id))
        db.add(ChatMember(chat_id=chat_id, user_id=recipient_id))
        await db.commit() # Фіксуємо створення
    else:
        print(f"DEBUG: Знайдено існуючий чат ID: {chat_id}")

    # 3. АНХАЙД: Видаляємо хайд для себе (працює і для знайденого, і для нового)
    await db.execute(
        delete(ChatHidden).where(
            and_(ChatHidden.chat_id == chat_id, ChatHidden.user_id == current_user_id)
        )
    )
    await db.commit()

    return {"chat_id": str(chat_id)}

@app.get("/messages/{chat_id}")
async def get_messages(
        chat_id: uuid.UUID,
        limit: int = Query(50, ge=1, le=100),
        offset: int = Query(0, ge=0),
        around_message_id: Optional[uuid.UUID] = Query(None),
        before_message_id: Optional[uuid.UUID] = Query(None), # Для довантаження старіших (вгору)
        after_message_id: Optional[uuid.UUID] = Query(None),  # Для довантаження новіших (вниз)
        db: AsyncSession = Depends(get_db),
        current_user_id: Optional[int] = Depends(get_current_user_id)
):
    likes_count_subq = (
        select(func.count(MessageReaction.id))
        .filter(MessageReaction.message_id == Message.id)
        .correlate(Message)
        .scalar_subquery()
    )

    is_liked_subquery = (
        select(MessageReaction.id)
        .filter(
            and_(
                MessageReaction.message_id == Message.id,
                MessageReaction.user_id == current_user_id
            )
        )
        .correlate(Message)
        .exists()
    ) if current_user_id else False

    target_message_ids = []

    # 1. Якщо запит йде НАСТУПНИХ (новіших) повідомлень вниз
    if after_message_id:
        anchor_res = await db.execute(select(Message.created_at).filter(Message.id == after_message_id))
        anchor_time = anchor_res.scalar()
        if anchor_time:
            stmt = (
                select(Message.id)
                .filter(Message.chat_id == chat_id, Message.created_at > anchor_time)
                .order_by(Message.created_at.asc())
                .limit(limit)
            )
            res = await db.execute(stmt)
            target_message_ids = [row[0] for row in res.all()]

    # 2. Якщо запит йде СТАРІШИХ повідомлень вгору (пагінація)
    elif before_message_id:
        anchor_res = await db.execute(select(Message.created_at).filter(Message.id == before_message_id))
        anchor_time = anchor_res.scalar()
        if anchor_time:
            stmt = (
                select(Message.id)
                .filter(Message.chat_id == chat_id, Message.created_at < anchor_time)
                .order_by(Message.created_at.desc())
                .limit(limit)
            )
            res = await db.execute(stmt)
            target_message_ids = [row[0] for row in res.all()][::-1]

    # 3. Первинний вхід або цільовий перехід навколо конкретного повідомлення
    else:
        if around_message_id:
            # Якщо чомусь треба відкрити конкретне повідомлення (наприклад, з пошуку)
            anchor_res = await db.execute(select(Message.created_at).filter(Message.id == around_message_id))
            target_anchor_time = anchor_res.scalar()
            if target_anchor_time:
                half_limit = limit // 2
                sub_older = (
                    select(Message.id)
                    .filter(Message.chat_id == chat_id, Message.created_at < target_anchor_time)
                    .order_by(Message.created_at.desc())
                    .limit(half_limit)
                    .subquery()
                )
                older_stmt = select(sub_older.c.id).order_by(select(Message.created_at).filter(Message.id == sub_older.c.id).scalar_subquery().asc())
                older_res = await db.execute(older_stmt)
                older_ids = [row[0] for row in older_res.all()]

                anchor_stmt = select(Message.id).filter(Message.chat_id == chat_id, Message.created_at == target_anchor_time).limit(1)
                anchor_res = await db.execute(anchor_stmt)
                anchor_id = anchor_res.scalar_one_or_none()

                remaining_limit = limit - len(older_ids) - (1 if anchor_id else 0)
                newer_stmt = (
                    select(Message.id)
                    .filter(Message.chat_id == chat_id, Message.created_at > target_anchor_time)
                    .order_by(Message.created_at.asc())
                    .limit(max(0, remaining_limit))
                )
                newer_res = await db.execute(newer_stmt)
                newer_ids = [row[0] for row in newer_res.all()]

                raw_ids = older_ids + ([anchor_id] if anchor_id else []) + newer_ids
                target_message_ids = list(dict.fromkeys(raw_ids))

        # Стандартний вхід у чат (offset == 0 без аругументів): просто віддаємо останні 50 штук з кінця
        if not target_message_ids:
            standard_stmt = (
                select(Message.id)
                .filter(Message.chat_id == chat_id)
                .order_by(Message.created_at.desc())
                .limit(limit)
                .offset(offset)
            )
            std_res = await db.execute(standard_stmt)
            target_message_ids = [row[0] for row in std_res.all()][::-1]

    if not target_message_ids:
        return []

    stmt = (
        select(
            Message,
            User.nickname.label("sender_nickname"),
            likes_count_subq.label("likes_count"),
            is_liked_subquery.label("is_liked_by_me")
        )
        .outerjoin(User, Message.sender_id == User.id)
        .filter(Message.id.in_(target_message_ids))
    )

    result = await db.execute(stmt)
    rows = result.all()

    messages_map = {}
    for row in rows:
        msg = row[0]
        sender_nickname = row[1]
        count = row[2]
        is_liked = row[3]

        msg_data = msg.__dict__.copy()
        msg_data.pop('_sa_instance_state', None)
        msg_data['sender_nickname'] = sender_nickname
        msg_data['likes_count'] = count or 0
        msg_data['is_liked_by_me'] = bool(is_liked)
        msg_data['chat_id'] = str(msg_data['chat_id'])
        msg_data['id'] = str(msg_data['id'])
        msg_data['sender_id'] = str(msg_data['sender_id'])

        messages_map[msg_data['id']] = msg_data

    ordered_messages = [messages_map[str(msg_id)] for msg_id in target_message_ids if str(msg_id) in messages_map]

    print(f"\n[GET_MESSAGES DEBUG] Віддаємо клієнту {len(ordered_messages)} повідомлень:")
    for m in ordered_messages:
        # Можеш підставити текст своїх проблемних повідомлень, наприклад від 843 до 845
        if m['content'] in ['843', '844', '845', '846', '847', '841', '840', '842']:
            print(f"   🔍 У БД для софт-тексту '{m['content']}' (ID: {m['id']}) стоїть статус: [ {m['status']} ]")

    return ordered_messages

@app.patch("/messages/read-up-to/{chat_id}")
async def mark_messages_up_to_as_read(
        chat_id: uuid.UUID,
        last_message_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    target_msg = await db.get(Message, last_message_id)
    if not target_msg:
        return {"status": "error", "detail": "Message not found"}

    # 1. Отримуємо поточний запис учасника чату для перевірки попереднього якоря
    member_result = await db.execute(
        select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user_id
        )
    )
    member_record = member_result.scalar_one_or_none()

    if member_record and member_record.last_read_message_id:
        current_last_read_msg = await db.get(Message, member_record.last_read_message_id)
        if current_last_read_msg and target_msg.created_at <= current_last_read_msg.created_at:
            return {
                "status": "ignored",
                "detail": "Requested message is older or equal to current read pointer",
                "unread_count": member_record.unread_count
            }

    # 2. Оновлюємо статус самих повідомлень (тільки ті, що до цільового включно)
    stmt = (
        update(Message)
        .where(
            Message.chat_id == chat_id,
            Message.sender_id != current_user_id,
            Message.status != "read",
            Message.created_at <= target_msg.created_at
        )
        .values(status="read")
    )
    result = await db.execute(stmt)

    # 3. Рахуємо реальний залишок непрочитаних для приватного чату
    unread_query = select(func.count(Message.id)).where(
        Message.chat_id == chat_id,
        Message.created_at > target_msg.created_at,
        Message.sender_id != current_user_id
    )
    unread_result = await db.execute(unread_query)
    remaining_unread = unread_result.scalar() or 0

    # 4. Оновлюємо ласт рід та реальний залишок unread_count у базі
    if member_record:
        member_record.last_read_message_id = last_message_id
        member_record.unread_count = remaining_unread

    await db.commit()

    # 5. Пушимо сокет
    await sio.emit('messages_read', {
        'chat_id': str(chat_id),
        'last_read_id': str(last_message_id),
        'unread_count': remaining_unread
    }, room=str(chat_id))

    return {
        "status": "ok",
        "updated_count": result.rowcount,
        "unread_count": remaining_unread
    }

@app.patch("/messages/group/read-up-to/{chat_id}")
async def mark_group_messages_up_to_as_read(
        chat_id: uuid.UUID,
        last_message_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    target_msg = await db.get(Message, last_message_id)
    if not target_msg:
        return {"status": "error", "detail": "Message not found"}

    # 1. Отримуємо поточний запис учасника чату, щоб перевірити попередній якір
    member_result = await db.execute(
        select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user_id
        )
    )
    member_record = member_result.scalar_one_or_none()

    if member_record and member_record.last_read_message_id:
        # Шукаємо попереднє прочитане повідомлення, яке вже збережене в базі
        current_last_read_msg = await db.get(Message, member_record.last_read_message_id)

        # 🛡️ ПЕРЕВІРКА: Якщо нове повідомлення старіше або рівне за те, що вже збережене — нічого не робимо!
        if current_last_read_msg and target_msg.created_at <= current_last_read_msg.created_at:
            return {
                "status": "ignored",
                "detail": "Requested message is older or equal to current read pointer",
                "unread_count": member_record.unread_count
            }

    # 2. Оновлюємо статус повідомлень у групі для всіх чужих повідомлень до цього часу включно
    stmt = (
        update(Message)
        .where(
            Message.chat_id == chat_id,
            Message.sender_id != current_user_id,
            Message.status != "read",
            Message.created_at <= target_msg.created_at
        )
        .values(status="read")
    )
    result = await db.execute(stmt)

    # 3. Рахуємо реальний залишок непрочитаних
    unread_query = select(func.count(Message.id)).where(
        Message.chat_id == chat_id,
        Message.created_at > target_msg.created_at,
        Message.sender_id != current_user_id
    )
    unread_result = await db.execute(unread_query)
    remaining_unread = unread_result.scalar() or 0

    # 4. Оновлюємо позицію в базі
    if member_record:
        member_record.last_read_message_id = last_message_id
        member_record.unread_count = remaining_unread

    await db.commit()

    # 5. Емітимо сокет іншим
    await sio.emit('messages_read', {
        'chat_id': str(chat_id),
        'user_id': current_user_id,
        'last_read_id': str(last_message_id),
        'unread_count': remaining_unread
    }, room=str(chat_id))

    return {"status": "ok", "updated_count": result.rowcount, "unread_count": remaining_unread}


@app.patch("/chats/{chat_id}/pin")
async def pin_message_in_chat(
        chat_id: uuid.UUID,
        data: dict,  # Очікуємо {"message_id": "uuid-повідомлення"} або ні, якщо відкріплюємо
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Перевіряємо, чи існує чат і чи користувач є його учасником
    member_check = await db.execute(
        select(ChatMember).filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id == current_user_id
        )
    )
    if not member_check.scalars().first():
        raise HTTPException(status_code=403, detail="Access denied")

    chat = await db.get(Chat, chat_id)
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    message_id_str = data.get("message_id")

    if message_id_str:
        message_id = uuid.UUID(message_id_str)
        # Перевіряємо, чи повідомлення взагалі існує в цьому чаті
        msg_check = await db.execute(
            select(Message).filter(
                Message.id == message_id,
                Message.chat_id == chat_id
            )
        )
        if not msg_check.scalars().first():
            raise HTTPException(status_code=404, detail="Message not found in this chat")

        chat.pinned_message_id = message_id
    else:
        # Якщо передали null або порожнє — відкріплюємо
        chat.pinned_message_id = None

    await db.commit()

    # 2. Емітимо подію через Socket.IO на всю кімнату чату
    await sio.emit('message_pinned', {
        'chat_id': str(chat_id),
        'pinned_message_id': str(chat.pinned_message_id) if chat.pinned_message_id else None
    }, room=str(chat_id))

    return {"status": "success", "pinned_message_id": str(chat.pinned_message_id) if chat.pinned_message_id else None}


@app.patch("/messages/{message_id}/read")
async def mark_single_message_as_read(
        message_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    print(f"\n[BACKEND DETECTIVE] ---> РЕКВЕСТ single-read <---")
    print(f"Message ID: {message_id}, Юзер, що читає (Мій ID): {current_user_id}")

    msg = await db.get(Message, message_id)
    if not msg:
        print(f"[BACKEND DETECTIVE] ❌ ПОМИЛКА: Повідомлення {message_id} не знайдено в БД!")
        return {"status": "error", "detail": "Message not found"}

    print(f"[BACKEND DETECTIVE] 🎯 Знайдено! Відправник повідомлення (Sender ID): {msg.sender_id}, Поточний статус в БД: {msg.status}")

    # Перевіряємо логіку дозволу на оновлення
    if msg.sender_id != current_user_id and msg.status != "read":
        print("[BACKEND DETECTIVE] 🛠️ Умова дозволяє оновлення. Пробуємо змінити на 'read'...")

        msg.status = "read"
        db.add(msg) # Явно додаємо в сесію для відстеження
        await db.commit()

        # Витягуємо свіжі дані прямо з бази, щоб переконатися, що запис ліг
        await db.refresh(msg)
        print(f"[BACKEND DETECTIVE] ✅ Успішний commit! Новий статус в базі: {msg.status}")

        await sio.emit('messages_read', {
            'chat_id': str(msg.chat_id),
            'last_read_id': str(message_id)
        }, room=str(msg.chat_id))
        print("[BACKEND DETECTIVE] 🚀 Сокет 'messages_read' відправлено!")
    else:
        print("[BACKEND DETECTIVE] ⚠️ ПРОПУСК ОНОВЛЕННЯ. Причини:")
        if msg.sender_id == current_user_id:
            print(f"   -> Це повідомлення написав я сам (мій ID = {current_user_id} == Sender ID = {msg.sender_id})")
        if msg.status == "read":
            print(f"   -> В базі статус ВЖЕ 'read'")

    return {"status": "ok"}

#Chat screen (chat list)
async def get_current_user(user_id: int = Depends(get_current_user_id), db: AsyncSession = Depends(get_db)):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# 2. Виправлений ендпоінт (використовуємо app, а не router)
@app.get("/chats/list")
async def get_chats(
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    hidden_chats_subquery = select(ChatHidden.chat_id).where(ChatHidden.user_id == current_user.id).scalar_subquery()

    result = await db.execute(
        select(Chat).join(ChatMember).where(ChatMember.user_id == current_user.id).where(Chat.id.not_in(hidden_chats_subquery))
    )
    chats = result.scalars().all()

    response = []
    for chat in chats:
        # Останнє повідомлення
        msg_res = await db.execute(
            select(Message).where(Message.chat_id == chat.id).order_by(desc(Message.created_at)).limit(1)
        )
        last_msg = msg_res.scalar_one_or_none()

        # === 🆕 БЕРЕМО unread_count ПРЯМО З ТАБЛИЦІ ChatMember ===
        member_res = await db.execute(
            select(ChatMember.unread_count).where(
                ChatMember.chat_id == chat.id,
                ChatMember.user_id == current_user.id
            )
        )
        unread_count = member_res.scalar() or 0
        # ========================================================

        # Отримуємо ВСІХ учасників цього чату
        members_res = await db.execute(
            select(User).join(ChatMember).where(ChatMember.chat_id == chat.id)
        )
        all_members = members_res.scalars().all()

        others = [u for u in all_members if u.id != current_user.id]

        members_data = [
            {"nickname": u.nickname, "avatar": u.avatar}
            for u in all_members[:4]
        ]

        # Функція перевірки онлайну за остантонім пінгом (менше 2 хвилин)
        def check_online(user):
            if not user or not user.last_seen:
                return False
            return (datetime.utcnow() - user.last_seen) < timedelta(minutes=2)

        response.append({
            "chat_id": str(chat.id),
            "title": chat.name if chat.is_group else (others[0].nickname if others else "Unknown"),
            "last_message": last_msg.content if last_msg else "Початок чату",
            "last_message_time": last_msg.created_at.isoformat() if last_msg else "",
            "unread_count": unread_count,
            "is_pro": others[0].is_pro if (not chat.is_group and others) else False,
            "is_online": check_online(others[0]) if (not chat.is_group and others) else False,
            "is_group": chat.is_group,
            "initials": [u.nickname[0].upper() for u in others[:4]],
            "last_message_status": last_msg.status if last_msg else "sent",
            "rating": others[0].rating if (not chat.is_group and others) else None,
            "recipient_id": others[0].id if (not chat.is_group and others) else None,
            "avatar_url": chat.avatar_url if chat.is_group else (others[0].avatar if others else None),
            "members": members_data
        })

    return response

#Options for Message#
@app.patch("/messages/{message_id}")
async def edit_message(
        message_id: str,
        data: dict, # Очікуємо {"content": "новий текст"}
        db: AsyncSession = Depends(get_db), # Змінено на AsyncSession
        current_user: User = Depends(get_current_user)
):
    # 1. Знаходимо повідомлення в БД асинхронно
    result = await db.execute(select(Message).filter(Message.id == message_id))
    message = result.scalars().first()

    # 2. Перевіряємо, чи воно існує і чи належить користувачу
    if not message or message.sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Не можна редагувати чуже повідомлення")

    # 3. Оновлюємо контент
    message.content = data['content']
    message.updated_at = datetime.utcnow()

    # 4. Асинхронний commit
    await db.commit()

    # 5. Оповіщаємо іншого користувача через Socket.io
    await sio.emit('message_edited', {
        'message_id': message_id,
        'new_content': message.content,
        'chat_id': str(message.chat_id) # переконайся, що chat_id конвертується в string
    }, room=str(message.chat_id))

    return {"status": "success"}

@app.post("/messages/{message_id}/react")
async def toggle_reaction(
        message_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id) # Використовуємо твій ID
):
    # 1. Шукаємо, чи вже є лайк від цього юзера
    stmt = select(MessageReaction).filter(
        MessageReaction.message_id == message_id,
        MessageReaction.user_id == current_user_id
    )
    result = await db.execute(stmt)
    existing = result.scalars().first()

    if existing:
        # Видаляємо (якщо вже є)
        await db.delete(existing)
        action = "removed"
    else:
        # Додаємо (якщо немає)
        new_reaction = MessageReaction(message_id=message_id, user_id=current_user_id)
        db.add(new_reaction)
        action = "added"

    await db.commit()

    # 2. Рахуємо загальну кількість лайків для цього повідомлення
    count_res = await db.execute(
        select(func.count(MessageReaction.id)).filter(MessageReaction.message_id == message_id)
    )
    count = count_res.scalar() or 0

    # 3. Емітимо подію в сокет
    msg_res = await db.execute(select(Message.chat_id).filter(Message.id == message_id))
    chat_id = msg_res.scalar()

    if chat_id:
        await sio.emit('reaction_updated', {
            'message_id': str(message_id),
            'count': count,
            'is_liked_by_me': action == 'added'
        }, room=str(chat_id))

    return {"status": "success", "action": action, "count": count}

@app.patch("/chats/{chat_id}/hide")
async def hide_chat(
        chat_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # Додаємо запис, що чат прихований для цього юзера
    hidden_chat = ChatHidden(user_id=current_user_id, chat_id=chat_id)
    db.add(hidden_chat)
    await db.commit()
    return {"status": "ok"}

@app.post("/messages/forward")
async def forward_message(
        data: dict,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    message_id = data.get("message_id")
    target_chat_ids = data.get("target_chat_ids")

    res = await db.execute(select(Message).filter(Message.id == message_id))
    original_msg = res.scalars().first()
    if not original_msg:
        raise HTTPException(status_code=404, detail="Message not found")

    # ДОДАЄМО: Шукаємо нікнейм того, хто відправив оригінал
    sender_res = await db.execute(select(User.nickname).filter(User.id == original_msg.sender_id))
    sender_nickname = sender_res.scalar() or "Unknown"

    for chat_id in target_chat_ids:
        # Зберігаємо у форматі: [FWD:Никнейм]Текст
        new_msg = Message(
            chat_id=chat_id,
            sender_id=current_user_id,
            content=f"[FWD:{sender_nickname}]{original_msg.content}",
            status="sent"
        )
        db.add(new_msg)

        # === 🆕 ЗБІЛЬШУЄМО unread_count ДЛЯ ІНШИХ УЧАСНИКІВ У ЦЬОМУ ЧАТІ ===
        await db.execute(
            update(ChatMember)
            .where(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id != current_user_id
            )
            .values(unread_count=ChatMember.unread_count + 1)
        )
        # ================================================================
        unread_res = await db.execute(
            select(func.max(ChatMember.unread_count)).where(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id != current_user_id
            )
        )
        current_unread = unread_res.scalar() or 1

        await sio.emit('new_message', {
            'chat_id': str(chat_id),
            'content': new_msg.content,
            'sender_id': current_user_id,
            'created_at': datetime.utcnow().isoformat(),
            'unread_count': current_unread
        }, room=str(chat_id))

    await db.commit()
    return {"status": "success"}

@app.delete("/messages/{message_id}")
async def delete_message(
        message_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    # 1. Знаходимо повідомлення
    result = await db.execute(select(Message).filter(Message.id == message_id))
    message = result.scalars().first()

    # 2. Перевірка: чи воно існує і чи належить користувачу
    if not message or message.sender_id != current_user.id:
        raise HTTPException(status_code=403, detail="Не можна видалити це повідомлення")

    chat_id = message.chat_id

    # Якщо видалене повідомлення ще НЕ було прочитане іншим учасником зменшуємо кількість непрочитаних
    if message.status != "read":
        await db.execute(
            update(ChatMember)
            .where(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id != current_user.id,
                ChatMember.unread_count > 0  # Захист від від'ємних чисел
            )
            .values(unread_count=ChatMember.unread_count - 1)
        )

    # 3. Видаляємо з БД
    await db.delete(message)
    await db.commit()

    # 4. Оповіщаємо іншого користувача через Socket.io, щоб видалити його в реальному часі
    await sio.emit('message_deleted', {
        'message_id': str(message_id),
        'chat_id': str(chat_id)
    }, room=str(chat_id))

    return {"status": "success"}

@app.post("/chats/create-group")
async def create_group_chat(
        data: dict,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    name = data.get("name", "New Group")
    target_user_ids = list(set(data.get("user_ids", []) + [current_user_id]))

    # Використовуємо функцію ANY для порівняння з масивом (ARRAY)
    # count - це кількість учасників, яку ми очікуємо
    # uids - це список ID учасників
    stmt = text("""
        SELECT cm.chat_id 
        FROM chat_members cm
        JOIN chats c ON cm.chat_id = c.id
        WHERE c.is_group = TRUE
        GROUP BY cm.chat_id
        HAVING COUNT(DISTINCT cm.user_id) = :count
        AND COUNT(DISTINCT CASE WHEN cm.user_id = ANY(:uids) THEN cm.user_id END) = :count
    """)

    # У PostgreSQL масиви передаються як списки (у Python-списках)
    res = await db.execute(stmt, {
        "uids": target_user_ids,
        "count": len(target_user_ids)
    })
    existing_chat_id = res.scalar()

    if existing_chat_id:
        # ОСЬ ТУТ КЛЮЧОВИЙ МОМЕНТ:
        # Ми знайшли старий чат, який ти колись захайдав.
        # Видаляємо хайд для себе, щоб він знову з'явився у тебе в списку.
        await db.execute(
            delete(ChatHidden).where(
                and_(ChatHidden.chat_id == existing_chat_id, ChatHidden.user_id == current_user_id)
            )
        )
        await db.commit()
        return {"chat_id": str(existing_chat_id)}

    # Якщо чату немає — створюємо новий
    new_chat = Chat(name=name, is_group=True, admin_id=current_user_id)
    db.add(new_chat)
    await db.flush()

    for uid in target_user_ids:
        # 🔥 Якщо це той, хто створив групу — робимо його адміном і в ChatMember
        is_user_admin = (uid == current_user_id)
        db.add(ChatMember(chat_id=new_chat.id, user_id=uid, is_admin=is_user_admin))

    await db.commit()
    return {"chat_id": str(new_chat.id)}

@app.get("/chats/{chat_id}/info")
async def get_chat_info(
        chat_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    result = await db.execute(select(Chat).filter(Chat.id == chat_id))
    chat = result.scalars().first()
    if not chat: raise HTTPException(status_code=404, detail="Chat not found")

    # 📌 Шукаємо закріплене повідомлення, якщо воно є
    pinned_message_data = None
    if chat.pinned_message_id:
        msg_res = await db.execute(
            select(Message, User.nickname.label("sender_nickname"))
            .outerjoin(User, Message.sender_id == User.id)
            .filter(Message.id == chat.pinned_message_id)
        )
        row = msg_res.first()
        if row:
            msg, sender_nickname = row
            pinned_message_data = {
                "id": str(msg.id),
                "content": msg.content,
                "sender_nickname": sender_nickname or "Unknown"
            }

    # Отримуємо учасників, тепер з даними про те, чи вони адміни
    stmt = select(User, ChatMember.is_admin).join(ChatMember).filter(ChatMember.chat_id == chat_id)
    res = await db.execute(stmt)
    members = res.all()

    def check_online(user):
        if not user or not user.last_seen:
            return False
        return (datetime.utcnow() - user.last_seen) < timedelta(minutes=2)

    members_data = []
    is_me_admin = False
    for user, is_admin in members:
        if user.id == current_user_id: is_me_admin = is_admin
        members_data.append({
            "id": user.id,
            "nickname": user.nickname,
            "is_admin": is_admin,
            "avatar": user.avatar,
            "is_online": check_online(user)  # 🔥 Додаємо поле, яке чесно каже, чи юзер онлайн
        })

    return {
        "chat_id": str(chat.id),
        "name": chat.name,
        "members": members_data,
        "is_me_admin": is_me_admin,
        "avatar_url": chat.avatar_url,
        "pinned_message": pinned_message_data
    }
# Ендпоінт для оновлення назви групи
@app.patch("/group_chats/{chat_id}/name")
async def update_chat_name(
        chat_id: uuid.UUID,
        data: dict, # Очікуємо {"name": "New Name"}
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    result = await db.execute(select(Chat).filter(Chat.id == chat_id))
    chat = result.scalars().first()

    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # Перевіряємо, чи юзер адмін
    if chat.admin_id != current_user_id:
        raise HTTPException(status_code=403, detail="Only admin can change group name")

    chat.name = data.get("name", chat.name)
    await db.commit()
    return {"status": "success", "new_name": chat.name}

# Ендпоінт для завантаження аватарки групи
@app.post("/group_chats/{chat_id}/avatar")
async def upload_chat_avatar(
        chat_id: uuid.UUID,
        file: UploadFile = File(...),
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Знаходимо чат
    result = await db.execute(select(Chat).filter(Chat.id == chat_id))
    chat = result.scalars().first()
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    # Перевірка адміна
    if chat.admin_id != current_user_id:
        raise HTTPException(status_code=403, detail="Only admin can change avatar")

    os.makedirs("uploads/avatars", exist_ok=True)

    # 2. Зберігаємо файл
    file_extension = file.filename.split(".")[-1]
    file_name = f"group_{chat_id}_{uuid.uuid4()}.{file_extension}"
    file_location = f"uploads/avatars/{file_name}"

    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 3. Оновлюємо посилання в базі
    chat.avatar_url = f"/{file_location}"
    await db.commit()

    return {"url": chat.avatar_url}

@app.delete("/group_chats/{chat_id}/leave")
async def leave_group_chat(
        chat_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Знаходимо чат та учасника
    res_chat = await db.execute(select(Chat).filter(Chat.id == chat_id))
    chat = res_chat.scalars().first()

    res_member = await db.execute(select(ChatMember).filter(ChatMember.chat_id == chat_id, ChatMember.user_id == current_user_id))
    member = res_member.scalars().first()

    if not chat or not member:
        raise HTTPException(status_code=404, detail="Chat or member not found")

    # 2. Якщо виходить адмін
    if chat.admin_id == current_user_id:
        # Шукаємо інших адмінів, крім нас
        stmt_others = select(ChatMember).filter(
            ChatMember.chat_id == chat_id,
            ChatMember.user_id != current_user_id,
            ChatMember.is_admin == True
        ).limit(1)
        others_res = await db.execute(stmt_others)
        next_admin = others_res.scalars().first()

        if next_admin:
            # Передаємо адмінство іншому адміну
            chat.admin_id = next_admin.user_id
        else:
            # Якщо інших адмінів немає, шукаємо будь-якого іншого учасника
            stmt_any = select(ChatMember).filter(ChatMember.chat_id == chat_id, ChatMember.user_id != current_user_id).limit(1)
            any_res = await db.execute(stmt_any)
            fallback = any_res.scalars().first()

            if fallback:
                chat.admin_id = fallback.user_id
            else:
                # 3. Якщо учасників більше немає — вимикаємо світло
                await db.delete(chat)
                await db.commit()
                return {"status": "chat_deleted"}

    # 4. Видаляємо поточного користувача
    await db.delete(member)
    await db.commit()

    # 5. Еміт події про вихід
    await sio.emit('user_left', {
        'chat_id': str(chat_id),
        'user_id': current_user_id
    }, room=str(chat_id))

    return {"status": "left"}


# Додати адміна
@app.post("/group_chats/{chat_id}/members/{member_id}/admin")
async def make_admin(
        chat_id: uuid.UUID,
        member_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Виконуємо запит один раз і зберігаємо результат у змінну
    stmt = select(ChatMember).filter(ChatMember.chat_id == chat_id, ChatMember.user_id == current_user_id)
    result = await db.execute(stmt)
    me = result.scalars().first()

    # 2. Тепер перевіряємо змінну 'me'
    if not me or not me.is_admin:
        raise HTTPException(status_code=403, detail="Not an admin")

    # 3. Оновлюємо статус іншого користувача
    await db.execute(
        update(ChatMember)
        .where(ChatMember.chat_id == chat_id, ChatMember.user_id == member_id)
        .values(is_admin=True)
    )
    await db.commit()
    return {"status": "success"}

# Зняти адміна
@app.delete("/group_chats/{chat_id}/members/{member_id}/admin")
async def remove_admin(chat_id: uuid.UUID, member_id: int, db: AsyncSession = Depends(get_db), current_user_id: int = Depends(get_current_user_id)):
    # Аналогічна перевірка...
    await db.execute(update(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == member_id).values(is_admin=False))
    await db.commit()
    return {"status": "success"}

# Ендпоінт для видалення учасника з групи
@app.delete("/group_chats/{chat_id}/members/{member_id}")
async def remove_member(
        chat_id: uuid.UUID,
        member_id: int,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    # 1. Перевірка адмінства
    result = await db.execute(select(Chat).filter(Chat.id == chat_id))
    chat = result.scalars().first()
    if not chat or chat.admin_id != current_user_id:
        raise HTTPException(status_code=403, detail="Only admin can remove members")

    # 2. Перевірка, чи це не видалення самого себе (для цього є /leave)
    if member_id == current_user_id:
        raise HTTPException(status_code=400, detail="Use leave endpoint to remove yourself")

    # 3. Видалення з ChatMember
    stmt = delete(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == member_id)
    result = await db.execute(stmt)

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Member not found in chat")

    await db.commit()
    return {"status": "removed"}

#Додаємо юзерів до групового чату:
@app.post("/group_chats/{chat_id}/add-members")
async def add_members(
        chat_id: uuid.UUID,
        data: dict,
        db: AsyncSession = Depends(get_db)
):
    user_ids = data.get("user_ids", [])
    for uid in user_ids:
        # Перевіряємо чи він ще не там (щоб не було помилки унікальності)
        existing = await db.execute(select(ChatMember).filter(ChatMember.chat_id == chat_id, ChatMember.user_id == uid))
        if not existing.scalars().first():
            db.add(ChatMember(chat_id=chat_id, user_id=uid, is_admin=False))

    await db.commit()
    return {"status": "success"}

@app.get("/chats/{chat_id}/search")
async def search_messages(
        chat_id: uuid.UUID,
        query: str,
        db: AsyncSession = Depends(get_db)
):
    # Шукаємо в контенті повідомлень
    stmt = select(Message).filter(
        Message.chat_id == chat_id,
        Message.content.ilike(f"%{query}%")
    ).order_by(Message.created_at.desc())

    result = await db.execute(stmt)
    messages = result.scalars().all()

    # Повертаємо знайдені повідомлення
    return [{"id": str(m.id), "content": m.content, "created_at": m.created_at.isoformat()} for m in messages]

#PRO Notifications.

@app.post("/pro/activate")
async def activate_pro(
        data: dict, # Очікуємо {"trial": true/false}
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    user = await db.get(User, current_user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    is_trial = data.get("trial", False)
    base_time = datetime.utcnow()

    # Накопичення днів/годин: якщо PRO ще активний, плюсуємо до його кінця
    if user.is_pro and user.pro_expiry_date and user.pro_expiry_date > base_time:
        base_time = user.pro_expiry_date

    if is_trial:
        if user.pro_trial_used:
            raise HTTPException(status_code=400, detail="Trial already used")
        user.pro_trial_used = True
        user.is_pro = True
        user.pro_expiry_date = base_time + timedelta(days=7) # Тріал залишаємо 7 днів (або теж можна скоротити, якщо треба)
    else:
        user.is_pro = True
        # === ТЕСТОВИЙ РЕЖИМ: 6 годин замість 30 днів ===
        user.pro_expiry_date = base_time + timedelta(hours=6)

    # Нотифікація про активацію (activated)
    new_notif = Notification(
        id=str(uuid.uuid4()),
        recipient_id=current_user_id,
        sender_id=current_user_id,
        message="Welcome to PRO! Enjoy your advanced filters.",
        type="pro",
        state="pending",
        game="activated",
        created_at=datetime.utcnow()
    )
    db.add(new_notif)
    await db.commit()

    await sio.emit('new_notification', {
        "id": new_notif.id,
        "user_nickname": user.nickname,
        "message": new_notif.message,
        "type": new_notif.type,
        "state": new_notif.state,
        "game": new_notif.game,
        "sender_id": str(current_user_id),
        "time": new_notif.created_at.isoformat()
    }, room=str(current_user_id))

    return {"status": "success", "is_pro": user.is_pro, "expiry_date": user.pro_expiry_date.isoformat()}

# File attachment
@app.post("/chats/{chat_id}/upload")
async def upload_chat_file(
        chat_id: str,
        file: UploadFile = File(...),
        user = Depends(get_current_user),
        db: AsyncSession = Depends(get_db)
):
    MAX_FILE_SIZE = 1 * 1024 * 1024
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="File size exceeds the 1MB limit."
        )

    os.makedirs("uploads/chat_files", exist_ok=True)

    original_filename = file.filename or "file" # <--- Зберігаємо оригінальне ім'я
    file_extension = original_filename.split(".")[-1] if "." in original_filename else "bin"
    unique_filename = f"{uuid.uuid4()}.{file_extension}"
    file_location = f"uploads/chat_files/{unique_filename}"

    with open(file_location, "wb") as buffer:
        buffer.write(contents)

    # Повертаємо і шлях, і оригінальну назву
    return {
        "file_url": f"/uploads/chat_files/{unique_filename}",
        "file_name": original_filename
    }

@app.get("/chats/{chat_id}/search")
async def search_messages_in_chat(
        chat_id: uuid.UUID,
        query: str,
        db: AsyncSession = Depends(get_db)
):
    stmt = select(Message).filter(
        Message.chat_id == chat_id,
        Message.content.ilike(f"%{query}%")
    ).order_by(Message.created_at.desc())

    result = await db.execute(stmt)
    messages = result.scalars().all()

    return [{"id": str(m.id), "content": m.content, "created_at": m.created_at.isoformat()} for m in messages]

@app.get("/chats/{chat_id}/unread-count")
async def get_chat_unread_count(
        chat_id: uuid.UUID,
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    stmt = (
        select(func.count(Message.id))
        .filter(
            Message.chat_id == chat_id,
            Message.sender_id != current_user_id,
            Message.status != "read"
        )
    )
    result = await db.execute(stmt)
    count = result.scalar() or 0
    return {"unread_count": count}

@app.post("/users/ping")
async def user_ping(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    user = await db.get(User, current_user_id)
    if user:
        was_offline = not user.is_online

        user.is_online = True
        user.last_seen = datetime.utcnow()
        await db.commit()

        # 🚀 Емітимо глобальну сокет-подію, щоб усі клієнти бачили актуальний онлайн
        await sio.emit('user_status_changed', {
            "user_id": current_user_id,
            "is_online": True,
            "last_seen": user.last_seen.isoformat()
        })

    return {"status": "ok"}

@app.post("/users/logout")
async def logout_user(
        db: AsyncSession = Depends(get_db),
        current_user_id: int = Depends(get_current_user_id)
):
    user = await db.get(User, current_user_id)
    if user:
        user.is_online = False
        user.last_seen = datetime.utcnow()
        await db.commit()

        # 🚀 Миттєво сповіщаємо всіх через сокет, що юзер вийшов
        await sio.emit('user_status_changed', {
            "user_id": current_user_id,
            "is_online": False,
            "last_seen": user.last_seen.isoformat()
        })

    return {"status": "success", "message": "Logged out successfully"}


@app.post("/auth/resend-verification")
async def resend_verification(data: dict, db: AsyncSession = Depends(get_db)):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    # Якщо користувач існує і ще не верифікований — оновлюємо токен і час
    if user and not user.is_verified:
        verification_token = str(uuid.uuid4())
        user.verification_token = verification_token
        user.created_at = datetime.utcnow() # Оновлюємо час, щоб 24 години на перевірку пішли заново
        await db.commit()

        send_verification_email(user.email, verification_token)

    return {"status": "success", "message": "Verification email resent if user exists."}



##FORGOT Password. Password Reset block####
def send_reset_password_email(to_email: str, token: str):
    smtp_host = os.getenv("SMTP_HOST", "localhost")
    smtp_port = int(os.getenv("SMTP_PORT", "1025"))

    # Посилання на сторінку скидання пароля на нашому бекенді
    reset_link = f"http://192.168.0.229:8000/auth/reset-password?token={token}"

    msg = EmailMessage()
    msg['Subject'] = "Reset your password - GAME BUDDY"
    msg['From'] = "noreply@gamebuddy.com"
    msg['To'] = to_email

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Reset Password</title>
        <style>
            body {{ background-color: #0F0F13; margin: 0; padding: 0; font-family: 'Poppins', Arial, sans-serif; color: #FFFFFF; }}
            .container {{ max-width: 600px; margin: 0 auto; padding: 40px 20px; text-align: center; }}
            .content-box {{ text-align: center; color: #FFFFFF; font-size: 16px; line-height: 27px; }}
            .verify-btn {{ display: inline-block; font-weight: 700; font-size: 20px; color: #00F5A0 !important; text-decoration: none; margin: 35px 0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>Password Reset Request</h2>
            <div class="content-box">
                <p>We received a request to reset your password. Click the button below to set a new password:</p>
                <div>
                    <a href="{reset_link}" class="verify-btn">Reset Password</a>
                </div>
                <p>This link is valid for 20 minutes. If you didn't request this, simply ignore this email.</p>
            </div>
        </div>
    </body>
    </html>
    """
    msg.set_content("Please reset your password by visiting the link.")
    msg.add_alternative(html_content, subtype='html')

    try:
        with smtplib.SMTP(smtp_host, smtp_port) as server:
            server.send_message(msg)
        print(f"✅ [MAILPIT] Лист для скидання пароля надіслано на {to_email}")
    except Exception as e:
        print(f"❌ [MAILPIT] Помилка відправки листа: {e}")

@app.post("/auth/forgot-password")
async def forgot_password(data: dict, db: AsyncSession = Depends(get_db)):
    email = data.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Email is required")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalars().first()

    # Навіть якщо юзера немає, краще повернути успіх задля безпеки (щоб не зливати балу пошт)
    if user:
        token = str(uuid.uuid4())
        user.reset_password_token = token
        user.reset_password_expires = datetime.utcnow() + timedelta(minutes=20) # Дійсний 20 хвилин
        await db.commit()

        send_reset_password_email(user.email, token)

    return {"status": "success", "message": "If the email exists, a reset link has been sent."}


@app.get("/auth/reset-password", response_class=HTMLResponse)
async def reset_password_page(token: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.reset_password_token == token))
    user = result.scalars().first()

    if not user or not user.reset_password_expires or user.reset_password_expires < datetime.utcnow():
        return """
        <html><body style="background-color: #0F0F13; color: #FF3B5C; text-align: center; padding-top: 50px; font-family: sans-serif;">
            <h2>Invalid or expired reset link.</h2>
            <p style="color: #A3A3B5;">Please request a new password reset from the app.</p>
        </body></html>
        """

    # Відображаємо гарну HTML-форму для введення нового пароля
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <title>Reset Password</title>
        <style>
            body {{ background-color: #0F0F13; color: white; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }}
            .form-box {{ background: #181826; padding: 30px; border-radius: 12px; width: 100%; max-width: 400px; border: 1px solid #2B2B3B; text-align: center; }}
            input {{ width: 90%; padding: 12px; margin: 10px 0; background: #0F0F1A; border: 1px solid #2B2B3B; color: white; border-radius: 8px; }}
            button {{ background: #00F5A0; color: black; border: none; padding: 12px 20px; width: 100%; font-weight: bold; border-radius: 8px; cursor: pointer; margin-top: 15px; }}
        </style>
    </head>
    <body>
        <div class="form-box">
            <h2>Set New Password</h2>
            <form action="/auth/reset-password" method="POST">
                <input type="hidden" name="token" value="{token}">
                <input type="password" name="new_password" placeholder="New Password (min 6 chars)" required minlength="6">
                <button type="submit">Update Password</button>
            </form>
        </div>
    </body>
    </html>
    """


@app.post("/auth/reset-password", response_class=HTMLResponse)
async def submit_reset_password(token: str = Form(...), new_password: str = Form(...), db: AsyncSession = Depends(get_db)):
    # 🛡️ ВАЛІДАЦІЯ ПАРОЛЯ НА БЕКЕНДІ
    if len(new_password) < 6 or len(new_password) > 30:
        return """
        <html><body style="background-color: #0F0F13; color: #FF3B5C; text-align: center; padding-top: 50px; font-family: sans-serif;">
            <h2>Password must be between 6 and 30 characters.</h2>
            <p><a href="javascript:history.back()" style="color: #00F5A0;">Go back and try again</a></p>
        </body></html>
        """

    if ' ' in new_password:
        return """
        <html><body style="background-color: #0F0F13; color: #FF3B5C; text-align: center; padding-top: 50px; font-family: sans-serif;">
            <h2>Password cannot contain spaces.</h2>
            <p><a href="javascript:history.back()" style="color: #00F5A0;">Go back and try again</a></p>
        </body></html>
        """

    result = await db.execute(select(User).where(User.reset_password_token == token))
    user = result.scalars().first()

    if not user or not user.reset_password_expires or user.reset_password_expires < datetime.utcnow():
        return """
        <html><body style="background-color: #0F0F13; color: #FF3B5C; text-align: center; padding-top: 50px; font-family: sans-serif;">
            <h2>Link expired or invalid.</h2>
        </body></html>
        """

    # Оновлюємо пароль і стираємо використаний токен
    user.password = get_password_hash(new_password)
    user.reset_password_token = None
    user.reset_password_expires = None
    await db.commit()

    return """
    <html><body style="background-color: #0F0F13; color: white; text-align: center; padding-top: 50px; font-family: sans-serif;">
        <h2 style="color: #00F5A0;">Password successfully updated!</h2>
        <p style="color: #A3A3B5;">You can now return to the GAME BUDDY app and sign in with your new password.</p>
    </body></html>
    """

app = socketio.ASGIApp(sio, app)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)