from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '7c8285c648c6'
down_revision = '0ee788ea80dd'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Безпечно додаємо колонку, якщо її ще немає
    op.execute("""
        DO $$ 
        BEGIN 
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                Table_name = 'chats' AND column_name = 'pinned_message_id'
            ) THEN
                ALTER TABLE chats ADD COLUMN pinned_message_id UUID REFERENCES messages(id) ON DELETE SET NULL;
            END IF;
        END $$;
    """)

def downgrade() -> None:
    op.execute("ALTER TABLE chats DROP COLUMN IF EXISTS pinned_message_id;")