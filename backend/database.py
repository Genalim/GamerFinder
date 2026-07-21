from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base

#тут логін і пароль і база postgres: mysecretpassword: postgres"
#DATABASE_URL = "postgresql+asyncpg://postgres:mysecretpassword@localhost:5432/postgres"  - before docker
DATABASE_URL = "postgresql+asyncpg://postgres:mysecretpassword@db:5432/postgres"   #for docker

engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session