from peewee import *
from src.config import env
import datetime

db = SqliteDatabase(env['sqlite']['database'])

class BaseModel(Model):
    class Meta:
        database = db

class User(BaseModel):
    id = PrimaryKeyField()
    tg_user_id = BigIntegerField()
    tg_username = CharField()
    cookie = CharField(unique=True)
    cookie_user_id = CharField(unique=True)
    container_id = CharField(unique=True)
    created_at = DateTimeField(default=datetime.datetime.now)
    updated_at = DateTimeField(default=datetime.datetime.now)