import bcrypt
from jose import jwt
from datetime import datetime, timedelta
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials


# Секретний ключ (його нікому не кажи!)
SECRET_KEY = "my_super_secret_key_123"
ALGORITHM = "HS256"

# --- Твої існуючі функції хешування ---
def get_password_hash(password: str) -> str:
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    pwd_bytes = plain_password.encode('utf-8')
    hashed_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(pwd_bytes, hashed_bytes)

# --- Нова функція для JWT ---
def create_access_token(data: dict):
    to_encode = data.copy()
    # Токен діятиме 30 днів
    expire = datetime.utcnow() + timedelta(days=30)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

security = HTTPBearer()

async def get_current_user_id(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    print(f"DEBUG: Сервер отримав токен (довжина {len(token)}): {token[:10]}...")
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=403, detail="Невалідний токен")
        return int(user_id)
    except Exception:
        import traceback
        traceback.print_exc() # <--- ЦЕ ВИВЕДЕ ПРИЧИНУ 403
        raise HTTPException(status_code=403, detail="Помилка авторизації")

