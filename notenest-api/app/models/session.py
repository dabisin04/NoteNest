from datetime import datetime
import uuid
from app.config.db import db
from marshmallow import Schema, fields

class Session(db.Model):
    __tablename__ = 'sessions'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    token = db.Column(db.String(36), unique=True, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __init__(self, id=None, user_id=None, token=None, expires_at=None, created_at=None, updated_at=None):
        self.id = id or str(uuid.uuid4())
        self.user_id = user_id
        self.token = token
        self.expires_at = expires_at
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()

    def to_dict(self, camel_case=True):
        result = {
            'id': self.id,
            'userId': self.user_id if camel_case else self.user_id,
            'token': self.token,
            'expiresAt': self.expires_at.isoformat() if self.expires_at else None,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None
        }
        return result

    @staticmethod
    def from_dict(data):
        return Session(
            id=data.get('id'),
            user_id=data.get('userId') or data.get('user_id'),
            token=data.get('token'),
            expires_at=data.get('expiresAt') or data.get('expires_at'),
            created_at=data.get('createdAt') or data.get('created_at'),
            updated_at=data.get('updatedAt') or data.get('updated_at')
        )

class SessionSchema(Schema):
    id = fields.Str()
    userId = fields.Str(attribute='user_id')
    token = fields.Str()
    expiresAt = fields.DateTime(attribute='expires_at')
    createdAt = fields.DateTime(attribute='created_at')
    updatedAt = fields.DateTime(attribute='updated_at')
