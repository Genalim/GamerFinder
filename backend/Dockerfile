# Використовуємо офіційний легкий образ Python
FROM python:3.10-slim

# Встановлюємо робочу директорію всередині контейнера
WORKDIR /app

# Встановлюємо системні залежності (якщо потрібні для збірки бібліотек)
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Копіюємо файл залежностей та встановлюємо їх
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копіюємо весь решту коду бекенда
COPY . .

# Відкриваємо порт, на якому працює FastAPI
EXPOSE 8000

# Команда для запуску сервера
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]