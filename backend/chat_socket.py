import socketio
from datetime import datetime
import uuid
# Імпортуємо AsyncSessionLocal з твого database.py
from database import AsyncSessionLocal
from models import Message

sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')

@sio.event
async def join_chat(sid, data):
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

    # 1. Зберігаємо в БД, використовуючи твою фабрику сесій
    async with AsyncSessionLocal() as db:
        new_msg = Message(
            id=uuid.uuid4(),
            chat_id=chat_id,
            sender_id=sender_id,
            content=content,
            status="sent",
            created_at=datetime.utcnow()
        )
        db.add(new_msg)
        await db.commit()

    # 2. Робимо розсилку всім у кімнаті
    await sio.emit('new_message', {
        'chat_id': chat_id,
        'sender_id': sender_id,
        'content': content,
        'status': "sent",
        'created_at': datetime.utcnow().isoformat()
    }, room=chat_id)

    print(f"Повідомлення від {sender_id} в чаті {chat_id}: {content}")

#Typing indication for Chat.
@sio.on('typing')
async def typing(sid, data):
    chat_id = data.get('chat_id')
    # Відправляємо всім, хто в цій кімнаті, крім того, хто друкує
    await sio.emit('user_typing', {'chat_id': chat_id}, room=str(chat_id), skip_sid=sid)