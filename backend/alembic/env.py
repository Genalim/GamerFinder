from logging.config import fileConfig
import sys
import os
from sqlalchemy import pool, create_engine

# Додаємо корінь бекенду в шлях пошуку Python
current_dir = os.path.dirname(os.path.abspath(__file__))
backend_dir = os.path.dirname(current_dir)
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from alembic import context

# Абсолютний імпорт, який працює і для IDE, і для Docker
try:
    # Спроба для Docker (коли sys.path містить колір бекенду)
    from models import Base
except ImportError:
    # Спроба для PyCharm (коли він розглядає alembic як пакет)
    from ..models import Base

target_metadata = Base.metadata

# this is the Alembic Config object
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)


def run_migrations_offline() -> None:
    db_url = (
            os.getenv("DATABASE_URL")
            or os.getenv("ALEMIC_DATABASE_URL")
            or config.get_main_option("sqlalchemy.url")
    )
    db_url = db_url.replace("localhost", "gamerfinder_db")

    context.configure(
        url=db_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    db_url = (
            os.getenv("DATABASE_URL")
            or os.getenv("ALEMIC_DATABASE_URL")
            or config.get_main_option("sqlalchemy.url")
    )

    db_url = db_url.replace("localhost", "gamerfinder_db")
    db_url = db_url.replace("postgresql+asyncpg", "postgresql+psycopg2")

    connectable = create_engine(
        db_url,
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()