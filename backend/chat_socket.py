import socketio
from datetime import datetime
import uuid
# Імпортуємо AsyncSessionLocal з твого database.py
from database import AsyncSessionLocal
from models import Message
from sqlalchemy import select

sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')

@sio.event
async def join_chat(sid, data):
    print(f"DEBUG: Отримані дані сокета: {data}")
    chat_id = data.get('chat_id')
    await sio.enter_room(sid, room=chat_id)
    print(f"Користувач {sid} увійшов у чат {chat_id}")
    await sio.emit('joined', {'status': 'ok', 'room': chat_id}, to=sid)
    print(f"Користувач {sid} увійшов у чат {chat_id}")

@sio.event
async def send_message(sid, data):
    chat_id = data.get('chat_id')
    sender_id = int(data.get('sender_id'))
    content = data.get('content')
    reply_to_id = data.get('reply_to_id')

    # 1. Задаємо значення за замовчуванням
    sender_nickname = "User"

    async with AsyncSessionLocal() as db:
        # 2. Отримуємо нікнейм з БД
        from models import User
        result = await db.execute(select(User).filter_by(id=sender_id))
        user = result.scalar_one_or_none()
        if user:
            sender_nickname = user.nickname

        # 3. Створюємо повідомлення
        new_msg = Message(
            id=uuid.uuid4(),
            chat_id=chat_id,
            sender_id=sender_id,
            content=content,
            reply_to_id=reply_to_id,
            status="sent",
            created_at=datetime.utcnow()
        )
        db.add(new_msg)
        await db.commit()

    # 4. Тепер sender_nickname точно існує і доступний тут
    await sio.emit('new_message', {
        'id': str(new_msg.id),
        'chat_id': chat_id,
        'sender_id': sender_id,
        'sender_nickname': sender_nickname,
        'content': content,
        'reply_to_id': str(reply_to_id) if reply_to_id else None,
        'status': "sent",
        'created_at': new_msg.created_at.isoformat()
    }, room=chat_id)

#Typing indication for Chat.
@sio.on('typing')
async def typing(sid, data):
    chat_id = data.get('chat_id')
    # Відправляємо всім, хто в цій кімнаті, крім того, хто друкує
    await sio.emit('user_typing', {'chat_id': chat_id}, room=str(chat_id), skip_sid=sid)