import random
from datetime import datetime, timedelta
import asyncio
import pandas as pd
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from models import User, UserGames, UserLanguages, UserPlatforms, UserAvailability, UserStyles
from auth import get_password_hash

# 🛡️ Створюємо підключення спеціально для локального запуску через localhost
LOCAL_DATABASE_URL = "postgresql+asyncpg://postgres:mysecretpassword@localhost:5432/postgres"
engine = create_async_engine(LOCAL_DATABASE_URL, echo=False)

# Створюємо локальний генератор сесій
async_session_maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def seed_test_users_and_excel():
    async with async_session_maker() as db:
        print("🌱 Генерація юзерів від player10 до player60 з урахуванням твоїх ігор...")

        games_map = {
            1: "FIFA 22",
            2: "Valorant",
            3: "Counter-Strike: Global Offensive",
            4: "Roblox"
        }

        platforms_pool = ['PC', 'PS', 'Xbox', 'Mobile', 'Switch']
        languages_pool = ['Ukrainian', 'English', 'Polish', 'German']
        styles_pool = ['Casual', 'Competitive', 'Co-op', 'Training']
        all_hours = list(range(24))

        excel_rows = []

        for i in range(10, 61):
            nickname = f"player{i}"
            email = f"player{i}@gamebuddy.test"
            password_plain = "123456"

            existing = await db.execute(User.__table__.select().where(User.nickname == nickname))
            if existing.scalars().first():
                continue

            is_pro = random.choice([True, False, False])
            is_verified = True
            voice_chat = random.choice([True, False])
            rating = round(random.uniform(3.0, 5.0), 1)

            days_ago = random.randint(0, 5)
            last_seen = datetime.utcnow() - timedelta(days=days_ago, hours=random.randint(0, 23))

            new_user = User(
                nickname=nickname,
                email=email,
                password=get_password_hash(password_plain),
                avatar=None,
                voice_chat=voice_chat,
                _is_online=False,
                last_seen=last_seen,
                is_pro=is_pro,
                rating=rating,
                is_verified=is_verified,
                is_active=True,
                created_at=datetime.utcnow() - timedelta(days=random.randint(1, 30))
            )
            db.add(new_user)
            await db.flush()

            if i % 5 == 0:
                assigned_game_ids = [1, 2, 3, 4]
            elif i % 3 == 0:
                assigned_game_ids = [1, 2]
            elif i % 2 == 0:
                assigned_game_ids = [3, 4]
            else:
                assigned_game_ids = [random.choice([1, 2, 3, 4])]

            for g_id in assigned_game_ids:
                db.add(UserGames(user_id=new_user.id, game_id=g_id, style="default"))

            assigned_game_names = [games_map[g_id] for g_id in assigned_game_ids]

            user_platforms = random.sample(platforms_pool, k=random.randint(1, 2))
            for p in user_platforms:
                db.add(UserPlatforms(user_id=new_user.id, platform=p))

            user_langs = ['Ukrainian']
            if random.random() > 0.4:
                user_langs.append('English')
            for l in user_langs:
                db.add(UserLanguages(user_id=new_user.id, lang=l))

            user_styles = random.sample(styles_pool, k=random.randint(1, 2))
            for s in user_styles:
                db.add(UserStyles(user_id=new_user.id, style=s))

            user_hours = random.sample(all_hours, k=random.randint(4, 8))
            for h in user_hours:
                db.add(UserAvailability(user_id=new_user.id, utc_hour=h))

            excel_rows.append({
                "ID": new_user.id,
                "Nickname": nickname,
                "Email": email,
                "Password": password_plain,
                "Games": ", ".join(assigned_game_names),
                "Platforms": ", ".join(user_platforms),
                "Languages": ", ".join(user_langs),
                "Styles": ", ".join(user_styles),
                "Voice Chat": voice_chat,
                "PRO": is_pro,
                "Rating": rating,
                "Last Seen (Days Ago)": days_ago
            })

        await db.commit()
        print("✅ Успішно створено юзерів від player10 до player60 у базі даних!")

        df = pd.DataFrame(excel_rows)
        file_name = "test_users_data.xlsx"
        df.to_excel(file_name, index=False)
        print(f"📊 Ексель-файл успішно згенеровано та збережено як '{file_name}'!")

if __name__ == "__main__":
    asyncio.run(seed_test_users_and_excel())