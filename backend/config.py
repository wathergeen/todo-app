import os
from pathlib import Path

from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent
APP_ENV = os.getenv("APP_ENV", "dev").lower()

load_dotenv(BASE_DIR / f".env.{APP_ENV}")
load_dotenv(BASE_DIR / ".env", override=True)


def _read_bool(name, default=False):
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv("SQLALCHEMY_DATABASE_URI", "sqlite:///todo.db")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
    if not JWT_SECRET_KEY and APP_ENV == "test":
        JWT_SECRET_KEY = "test-secret-key-with-at-least-32-bytes"
    if not JWT_SECRET_KEY:
        raise RuntimeError("JWT_SECRET_KEY não definida")
    DEBUG = _read_bool("FLASK_DEBUG", False)
    SQLALCHEMY_TRACK_MODIFICATIONS = False


class TestConfig:
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    JWT_SECRET_KEY = "test-secret-key-with-at-least-32-bytes"
    DEBUG = False
    TESTING = True
    SQLALCHEMY_TRACK_MODIFICATIONS = False
