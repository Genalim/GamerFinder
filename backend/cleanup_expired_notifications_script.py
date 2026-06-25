import asyncio
import logging
from datetime import datetime, timedelta
from database import AsyncSessionLocal as async_session  # Імпортуємо ваш двигун БД
from models import Notification    # Імпортуємо модель
from sqlalchemy import delete

# Налаштування логування у файл
logging.basicConfig(
    filename='cleanup.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

async def run_cleanup():
    try:
        logging.info("Початок процесу очищення бази даних...")

        async with async_session() as db:
            # Визначаємо поріг: 30 днів
            #thirty_days_ago = datetime.utcnow() - timedelta(days=30)
            # СТАЛО ДЛЯ ТЕСТУ (20 хвилин):
            thirty_days_ago = datetime.utcnow() - timedelta(minutes=20)

            # Створюємо запит на видалення
            stmt = delete(Notification).filter(
                Notification.is_archived == True,
                Notification.created_at < thirty_days_ago
            )

            # Виконуємо
            result = await db.execute(stmt)
            await db.commit()

            # Логуємо результат
            count = result.rowcount
            logging.info(f"Очищення завершено. Видалено записів: {count}")
            print(f"Готово! Видалено {count} записів. Деталі у cleanup.log")

    except Exception as e:
        logging.error(f"Помилка під час очищення: {e}")
        print(f"Сталася помилка, дивіться cleanup.log: {e}")

if __name__ == "__main__":
    # Запуск асинхронної функції
    asyncio.run(run_cleanup())