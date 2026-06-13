from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, JSON, Float
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
    is_online = Column(Boolean, default=False)
    is_pro = Column(Boolean, default=False)
    rating = Column(Float, default=0.0)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)

    # Зв'язки (дозволяють робити user.availability тощо)
    availability = relationship("UserAvailability", backref="user")
    platforms = relationship("UserPlatforms", backref="user")
    languages = relationship("UserLanguages", backref="user")
    games = relationship("UserGames", backref="user")
    accounts = relationship("UserAccounts", backref="user")
    styles = relationship("UserStyles", backref="user")

class UserAvailability(Base):
    __tablename__ = "user_availability"
    user_id = Column(Integer, ForeignKey("users.id"), primary_key=True)
    utc_hour = Column(Integer, primary_key=True)

class UserPlatforms(Base):
    __tablename__ = "user_platforms"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    platform = Column(String)

class UserLanguages(Base):
    __tablename__ = "user_languages"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    lang = Column(String)

class UserGames(Base):
    __tablename__ = "user_games"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    game_id = Column(Integer, ForeignKey("games.id"))
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
    user_id = Column(Integer, ForeignKey("users.id"))
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

