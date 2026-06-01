from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, JSON
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
    rating = Column(Integer, default=0)
    is_verified = Column(Boolean, default=False)

    # Зв'язки (дозволяють робити user.availability тощо)
    availability = relationship("UserAvailability", backref="user")
    platforms = relationship("UserPlatforms", backref="user")
    languages = relationship("UserLanguages", backref="user")
    games = relationship("UserGames", backref="user")
    accounts = relationship("UserAccounts", backref="user")

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

class UserAccounts(Base):
    __tablename__ = "user_accounts"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    service = Column(String)
    username = Column(String)

class Game(Base):
    __tablename__ = "games"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True) # Назва має бути унікальною
    image_url = Column(String)
    genres = Column(JSON)

class UserStyles(Base):
    __tablename__ = "user_styles"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    style = Column(String)