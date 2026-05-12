from fastapi import FastAPI, Depends
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy import Column, Integer, String, select

# Налаштування підключення до Docker PostgreSQL
DATABASE_URL = "postgresql+asyncpg://postgres:mysecretpassword@localhost:5432/postgres"

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

# Опис таблиці ігор
class Game(Base):
    __tablename__ = "games_list"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, unique=True, nullable=False)

app = FastAPI(title="GamerFinder API")

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session

@app.get("/games")
async def get_games(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Game))
    games = result.scalars().all()
    return games

@app.get("/")
def read_root():
    return {"message": "Привіт, Геннадію! Сервер GamerFinder запущено."}

@app.get("/add_game/{name}")
async def add_game(name: str, db: AsyncSession = Depends(get_db)):
    new_game = Game(title=name)
    db.add(new_game)
    await db.commit()
    return {"message": f"Гру {name} додано в базу PostgreSQL!"}