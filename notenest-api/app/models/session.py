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

    def __init__(self, id=None, user_id=None, token=None, expires_at=None):
        self.id = id or str(uuid.uuid4())
        self.user_id = user_id
        self.token = token
        self.expires_at = expires_at

    def to_dict(self):
        return {
            'id': self.id,
            'userId': self.user_id,
            'token': self.token,
            'expiresAt': self.expires_at,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at
        }

    @staticmethod
    def from_dict(data):
        return Session(
            id=data.get('id'),
            user_id=data['userId'],
            token=data['token'],
            expires_at=data['expiresAt']
        )

class SessionSchema(Schema):
    id = fields.Str()
    user_id = fields.Str()
    token = fields.Str()
    expires_at = fields.DateTime()
    created_at = fields.DateTime()
    updated_at = fields.DateTime()

