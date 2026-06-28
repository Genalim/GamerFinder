import socketio

# Створюємо сервер тут
sio = socketio.AsyncServer(async_mode='asgi', cors_allowed_origins='*')

@sio.event
async def connect(sid, environ):
    print(f"Гравець підключився до чату: {sid}")

@sio.event
async def join_chat(sid, data):
    chat_id = data.get('chat_id')
    sio.enter_room(sid, room=chat_id)
    print(f"Користувач {sid} увійшов у кімнату {chat_id}")

@sio.event
async def disconnect(sid):
    print(f"Гравець відключився: {sid}")