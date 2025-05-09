from datetime import datetime
import uuid
from app.config.db import db
from marshmallow import Schema, fields

class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = db.Column(db.String(100), unique=True, nullable=False)
    name = db.Column(db.String(100), nullable=False)
    password_hash = db.Column(db.LargeBinary, nullable=False)
    salt = db.Column(db.LargeBinary, nullable=False)
    token = db.Column(db.String(36), unique=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __init__(self, id=None, email=None, name=None, password_hash=None, salt=None, token=None, created_at=None, updated_at=None):
        self.id = id or str(uuid.uuid4())
        self.email = email
        self.name = name
        self.password_hash = password_hash
        self.salt = salt
        self.token = token
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()

    def to_dict(self):
        return {
            'id': self.id,
            'email': self.email,
            'name': self.name,
            'passwordHash': self.password_hash,
            'token': self.token,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at
        }

    @staticmethod
    def from_dict(data):
        return User(
            id=data.get('id'),
            email=data['email'],
            name=data['name'],
            password_hash=data['passwordHash'],
            salt=data['salt'],
            token=data.get('token')
        )

class UserSchema(Schema):
    id = fields.Str()
    email = fields.Str()
    name = fields.Str()
    token = fields.Str()
    created_at = fields.DateTime()
    updated_at = fields.DateTime()
