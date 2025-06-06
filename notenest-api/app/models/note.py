from datetime import datetime
import uuid
from app.config.db import db
from marshmallow import Schema, fields

class Note(db.Model):
    __tablename__ = 'notes'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)
    is_public = db.Column(db.Boolean, default=False)
    likes = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __init__(self, id=None, user_id=None, title=None, content=None, is_public=False, likes=0, created_at=None, updated_at=None):
        self.id = id or str(uuid.uuid4())
        self.user_id = user_id
        self.title = title
        self.content = content
        self.is_public = is_public
        self.likes = likes
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()

    def to_dict(self, include_sensitive=False):
        return {
            '_id': self.id,  # útil para MongoDB
            'id': self.id,
            'userId': self.user_id,
            'title': self.title,
            'content': self.content,
            'isPublic': self.is_public,
            'likes': self.likes,
            'createdAt': self.created_at.isoformat() if self.created_at else None,
            'updatedAt': self.updated_at.isoformat() if self.updated_at else None
        }

    @staticmethod
    def from_dict(data):
        return Note(
            id=data.get('id') or data.get('_id'),
            user_id=data['userId'],
            title=data['title'],
            content=data.get('content'),
            is_public=data.get('isPublic', False),
            likes=data.get('likes', 0),
            created_at=datetime.fromisoformat(data['createdAt']) if data.get('createdAt') else None,
            updated_at=datetime.fromisoformat(data['updatedAt']) if data.get('updatedAt') else None
        )

# ✅ Esquema serializador Marshmallow con nombres camelCase
class NoteSchema(Schema):
    id = fields.Str()
    userId = fields.Str(attribute="user_id")
    title = fields.Str()
    content = fields.Str(allow_none=True)
    isPublic = fields.Bool(attribute="is_public")
    likes = fields.Int()
    createdAt = fields.DateTime(attribute="created_at")
    updatedAt = fields.DateTime(attribute="updated_at")
