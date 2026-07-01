"""change_user_id_type_to_integer

Revision ID: ba520d43c7c8
Revises: bde505f2e4f1
Create Date: 2026-06-30 15:51:17.794562

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ba520d43c7c8'
down_revision: Union[str, Sequence[str], None] = 'bde505f2e4f1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    op.alter_column('chat_members', 'user_id',
                    existing_type=sa.dialects.postgresql.UUID(as_uuid=True),
                    type_=sa.Integer(),
                    postgresql_using='user_id::text::integer', # Явне перетворення
                    existing_nullable=True)

    op.alter_column('messages', 'sender_id',
                    existing_type=sa.dialects.postgresql.UUID(as_uuid=True),
                    type_=sa.Integer(),
                    postgresql_using='sender_id::text::integer', # Явне перетворення
                    existing_nullable=True)

def downgrade():
    # Повернення назад (якщо знадобиться)
    op.alter_column('chat_members', 'user_id',
                    existing_type=sa.Integer(),
                    type_=sa.dialects.postgresql.UUID(as_uuid=True),
                    existing_nullable=True)

    op.alter_column('messages', 'sender_id',
                    existing_type=sa.Integer(),
                    type_=sa.dialects.postgresql.UUID(as_uuid=True),
                    existing_nullable=True)
