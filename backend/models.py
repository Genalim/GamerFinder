import uuid
from datetime import datetime, timedelta
from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, JSON, Float, DateTime, func, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    nickname = Column(String, unique=True, index=True)
    email = Column(String, unique=True)
    password = Column(String)
    avatar = Column(String, nullable=True)
    timezone_offset = Column(Integer, default=0)
    voice_chat = Column(Boolean, default=False)

    # ⚠️ Зберігаємо колонку в базі під капотом, але назвемо її _is_online,
    # щоб вона не конфліктувала з нашим динамічним property
    _is_online = Column("is_online", Boolean, default=False)

    last_seen = Column(DateTime, nullable=True)
    is_pro = Column(Boolean, default=False)
    pro_trial_used = Column(Boolean, default=False)
    pro_expiry_date = Column(DateTime, nullable=True)
    pro_trial_dismissed_at = Column(DateTime, nullable=True)
    rating = Column(Float, default=0.0)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)

    # 🚀 ДИНАМІЧНИЙ СТАТУС ОНЛАЙН
    @property
    def is_online(self) -> bool:
        if not self.last_seen:
            return False
        # Якщо з моменту останнього пінгу пройшло менше 2 хвилин — гравець в мережі
        return datetime.utcnow() - self.last_seen < timedelta(minutes=2)

    @is_online.setter
    def is_online(self, value: bool):
        # Дозволяємо SQLAlchemy записувати значення, якщо це десь потрібно в коді
        self._is_online = value

    # Зв'язки...
    availability = relationship("UserAvailability", backref="user")
    platforms = relationship("UserPlatforms", backref="user")
    languages = relationship("UserLanguages", backref="user")
    games = relationship("UserGames", backref="user")
    accounts = relationship("UserAccounts", backref="user")
    styles = relationship("UserStyles", backref="user")

class UserAvailability(Base):
    __tablename__ = "user_availability"
    # Додаємо index=True для швидкого пошуку за user_id
    user_id = Column(Integer, ForeignKey("users.id"), primary_key=True, index=True)
    utc_hour = Column(Integer, primary_key=True)

class UserPlatforms(Base):
    __tablename__ = "user_platforms"
    id = Column(Integer, primary_key=True, index=True)
    # Обов'язково додаємо index
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    platform = Column(String)

class UserLanguages(Base):
    __tablename__ = "user_languages"
    id = Column(Integer, primary_key=True, index=True)
    # Обов'язково додаємо index
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    lang = Column(String)

class UserGames(Base):
    __tablename__ = "user_games"
    id = Column(Integer, primary_key=True, index=True)
    # Обов'язково додаємо index
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    game_id = Column(Integer, ForeignKey("games.id"), index=True)
    style = Column(String)
    game = relationship("Game")

class UserAccounts(Base):
    __tablename__ = "user_accounts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    service = Column(String)
    username = Column(String)

class Game(Base):
    __tablename__ = "games"
    igdb_id = Column(Integer, index=True)
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True) # Назва має бути унікальною
    image_url = Column(String)
    genres = Column(JSON)

class UserStyles(Base):
    __tablename__ = "user_styles"
    id = Column(Integer, primary_key=True, index=True)
    # Обов'язково додаємо index
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    style = Column(String)

class Friendship(Base):
    __tablename__ = "friendships"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id")) # Хто відправив
    friend_id = Column(Integer, ForeignKey("users.id")) # Кому відправили
    status = Column(String, default="pending") # "pending", "accepted", "blocked"
    user = relationship("User", foreign_keys=[user_id])
    friend = relationship("User", foreign_keys=[friend_id])

class UserRating(Base):
    __tablename__ = "user_ratings"

    id = Column(Integer, primary_key=True, index=True)
    rater_id = Column(Integer, ForeignKey("users.id"), nullable=False) # Хто поставив оцінку
    rated_user_id = Column(Integer, ForeignKey("users.id"), nullable=False) # Кому поставили оцінку
    rating = Column(Integer, nullable=False) # Значення (наприклад, від 1 до 5)

    # Зв'язки (опціонально, за бажанням)
    rater = relationship("User", foreign_keys=[rater_id])
    rated_user = relationship("User", foreign_keys=[rated_user_id])

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String, primary_key=True, index=True)
    recipient_id = Column(Integer, ForeignKey("users.id"))
    sender_id = Column(Integer, ForeignKey("users.id"))
    message = Column(String)
    type = Column(String) # match, rating, pro
    state = Column(String, default="pending")
    game = Column(String)
    created_at = Column(DateTime, default=func.now())
    is_archived = Column(Boolean, default=False)

    # Зв'язки
    sender = relationship("User", foreign_keys=[sender_id])
    recipient = relationship("User", foreign_keys=[recipient_id])

class RatingRequest(Base):
    __tablename__ = "rating_requests"
    id = Column(Integer, primary_key=True)
    sender_id = Column(Integer, ForeignKey("users.id"))
    receiver_id = Column(Integer, ForeignKey("users.id"))
    game_id = Column(Integer, ForeignKey("games.id"))
    created_at = Column(DateTime, default=func.now())
    is_notification_sent = Column(Boolean, default=False) # Щоб відправити лише 1 раз
    is_rated = Column(Boolean, default=False)

#Chats
class Chat(Base):
    __tablename__ = 'chats'
    __table_args__ = {'extend_existing': True}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=True)
    is_group = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    admin_id = Column(Integer, ForeignKey('users.id'), nullable=True)
    avatar_url = Column(String, nullable=True)
    description = Column(String, nullable=True)

    # 🆕 ДОДАЄМО ПОЛЕ ДЛЯ ЗАКРІПЛЕНОГО ПОВІДОМЛЕННЯ
    pinned_message_id = Column(UUID(as_uuid=True), ForeignKey('messages.id', ondelete="SET NULL"), nullable=True)

class ChatMember(Base):
    __tablename__ = 'chat_members'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chat_id = Column(UUID(as_uuid=True), ForeignKey('chats.id'))
    user_id = Column(Integer, ForeignKey('users.id'))
    role = Column(String, default='member')
    is_admin = Column(Boolean, default=False, nullable=False)

    # 🆕 ПОЛЯ ДЛЯ ІНДИВІДУАЛЬНОГО ТРЕКІНГУ ПРОЧИТАНОГО:
    # Зберігає ID останнього повідомлення, яке цей конкретний користувач прочитав у цьому чаті
    last_read_message_id = Column(UUID(as_uuid=True), ForeignKey('messages.id'), nullable=True)
    # Персональна кількість непрочитаних для цього юзера в цьому чаті (для швидкого виведення бейджів)
    unread_count = Column(Integer, default=0)

class Message(Base):
    __tablename__ = 'messages'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chat_id = Column(UUID(as_uuid=True), ForeignKey('chats.id'))
    sender_id = Column(Integer, ForeignKey('users.id'))
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    # ⚠️ Примітка: глобальні полів is_read більше немає на повідомленні,
    # оскільки в групі воно може бути прочитане одним і не прочитане іншим.
    # Поле status залишаємо для статусу доставки на сервер ('sent').
    status = Column(String, default="sent")
    reply_to_id = Column(UUID(as_uuid=True), ForeignKey("messages.id"), nullable=True)
    reactions = relationship("MessageReaction", back_populates="message", cascade="all, delete-orphan")

class MessageReaction(Base):
    __tablename__ = 'message_reactions'
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4) # Виправ UUID на UUID(as_uuid=True)
    message_id = Column(UUID(as_uuid=True), ForeignKey('messages.id'), nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    reaction_type = Column(String, default='like')
    created_at = Column(DateTime, default=datetime.utcnow)
    message = relationship("Message", back_populates="reactions")



class ChatHidden(Base):
    __tablename__ = 'chat_hidden'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id'), index=True)
    chat_id = Column(UUID(as_uuid=True), ForeignKey('chats.id'), index=True)
    hidden_at = Column(DateTime, default=datetime.utcnow)



