import socketio
from datetime import datetime
import uuid
from database import AsyncSessionLocal
from models import Message, User, ChatHidden, ChatMember, Chat, Friendship
from sqlalchemy import select, delete, and_, or_, update

sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')

# Словник для зв'язку socket_id <-> user_id (потрібен, щоб знати, хто відключився)
active_connections = {}

@sio.event
async def join_chat(sid, data):
    print(f"DEBUG: Отримані дані сокета: {data}")
    chat_id = data.get('chat_id')
    user_id = data.get('user_id') # <--- Додай передачу user_id з фронту на всяк випадок

    if user_id and sid not in active_connections:
        active_connections[sid] = int(user_id)
        sio.enter_room(sid, room=str(user_id))

    await sio.enter_room(sid, room=chat_id)
    print(f"Користувач {sid} увійшов у чат {chat_id}")
    await sio.emit('joined', {'status': 'ok', 'room': chat_id}, to=sid)

@sio.event
async def send_message(sid, data):
    chat_id = data.get('chat_id')
    sender_id = int(data.get('sender_id'))
    content = data.get('content')
    reply_to_id = data.get('reply_to_id')

    sender_nickname = "User"

    async with AsyncSessionLocal() as db:
        # --- 1. ПЕРЕВІРКА НА БЛОКУВАННЯ ---
        chat_res = await db.execute(select(Chat).filter(Chat.id == chat_id))
        chat = chat_res.scalar_one_or_none()

        # Перевіряємо блок тільки якщо це приватний чат (не група)
        if chat and not chat.is_group:
            # Знаходимо співрозмовника
            stmt_members = select(ChatMember.user_id).where(
                and_(ChatMember.chat_id == chat_id, ChatMember.user_id != sender_id)
            )
            res = await db.execute(stmt_members)
            recipients = [m[0] for m in res.all()]

            if recipients:
                recipient_id = recipients[0]
                # Перевіряємо чи є блокування між цими двома
                stmt_block = select(Friendship).filter(
                    or_(
                        and_(Friendship.user_id == sender_id, Friendship.friend_id == recipient_id, Friendship.status == 'blocked'),
                        and_(Friendship.user_id == recipient_id, Friendship.friend_id == sender_id, Friendship.status == 'blocked')
                    )
                )
                is_blocked = await db.execute(stmt_block)
                if is_blocked.scalars().first():
                    # Якщо є блок - відправляємо помилку ЛИШЕ відправнику (to=sid) і припиняємо роботу
                    await sio.emit('error', {'message': 'You are blocked by this user!'}, to=sid)
                    return # БЛОКУЄМО ЗБЕРЕЖЕННЯ І ВІДПРАВКУ!

        # --- 2. ЯКЩО БЛОКУ НЕМАЄ, ПРАЦЮЄМО ДАЛІ ---
        result = await db.execute(select(User).filter_by(id=sender_id))
        user = result.scalar_one_or_none()
        if user:
            sender_nickname = user.nickname
            # Оновлюємо статус і час активності, коли юзер пише повідомлення
            user.is_online = True
            user.last_seen = datetime.utcnow()

        # Створюємо повідомлення
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

        # ЛОГІКА "ОЖИВЛЕННЯ" ЧАТУ
        await db.execute(
            delete(ChatHidden).where(ChatHidden.chat_id == chat_id)
        )

        # === ЗБІЛЬШУЄМО unread_count ДЛЯ ВСІХ ІНШИХ УЧАСНИКІВ ЧАТУ ===
        await db.execute(
            update(ChatMember)
            .where(
                ChatMember.chat_id == chat_id,
                ChatMember.user_id != sender_id
            )
            .values(unread_count=ChatMember.unread_count + 1)
        )

        await db.commit()

    # Емітимо повідомлення всім у кімнаті
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


# =====================================================================
# ПІДКЛЮЧЕННЯ / ВІДКЛЮЧЕННЯ (Оновлення is_online та last_seen)
# =====================================================================

@sio.event
async def connect(sid, environ, auth=None):
    user_id = None

    # 1. Спробуємо взяти user_id з auth
    if auth and isinstance(auth, dict):
        user_id = auth.get('user_id')

    # 2. Якщо в auth немає, парсимо з query-параметрів URL
    if not user_id:
        query_string = environ.get('QUERY_STRING', '')
        if 'user_id=' in query_string:
            try:
                user_id = query_string.split('user_id=')[1].split('&')[0]
            except Exception:
                pass

    if user_id:
        user_id_int = int(user_id)
        active_connections[sid] = user_id_int  # Зберігаємо зв'язок в оперативній пам'яті

        await sio.enter_room(sid, room=str(user_id_int))

        # Оновлюємо статус в БД: ставимо Онлайн і фіксуємо останній час
        async with AsyncSessionLocal() as db:
            user = await db.get(User, user_id_int)
            if user:
                user.is_online = True
                user.last_seen = datetime.utcnow()
                await db.commit()
                print(f"Користувач {user_id_int} (sid: {sid}) підключився -> ОНЛАЙН")

                await sio.emit('user_status_changed', {
                    "user_id": user_id_int,
                    "is_online": True,
                    "last_seen": user.last_seen.isoformat()
                })
    else:
        print(f"Підключення без user_id для sid {sid}")

@sio.event
async def disconnect(sid):
    # Шукаємо, який саме юзер відключився за цим sid
    user_id = active_connections.pop(sid, None)

    if user_id:
        async with AsyncSessionLocal() as db:
            user = await db.get(User, user_id)
            if user:
                user.is_online = False
                user.last_seen = datetime.utcnow() # Фіксуємо точний час виходу
                await db.commit()
                print(f"Користувач {user_id} (sid: {sid}) відключився -> ОФЛАЙН")

                await sio.emit('user_status_changed', {
                    "user_id": user_id,
                    "is_online": False,
                    "last_seen": user.last_seen.isoformat()
                })
    else:
        print(f"Відключився невідомий sid: {sid}")