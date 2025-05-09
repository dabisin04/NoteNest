from datetime import datetime
import uuid
from app.config.db import db
from marshmallow import Schema, fields

class Comment(db.Model):
    __tablename__ = "comments"

    id           = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id      = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    user_name    = db.Column(db.String(100))
    note_id      = db.Column(db.String(36), db.ForeignKey("notes.id"), nullable=False)
    parent_id    = db.Column(db.String(36), db.ForeignKey("comments.id"))
    root_comment = db.Column(db.String(36), nullable=False)
    content      = db.Column(db.Text,      nullable=False)
    created_at   = db.Column(db.DateTime,  default=datetime.utcnow)
    updated_at   = db.Column(db.DateTime,  default=datetime.utcnow, onupdate=datetime.utcnow)

    user = db.relationship("User", backref="comments", lazy="joined")

    def __init__(
        self,
        id=None,
        user_id=None,
        user_name=None,
        note_id=None,
        parent_id=None,
        content=None,
        root_comment=None,
        created_at=None,
        updated_at=None,
    ):
        now = datetime.utcnow()
        self.id           = id or str(uuid.uuid4())
        self.user_id      = user_id
        self.user_name    = user_name
        self.note_id      = note_id
        self.parent_id    = parent_id
        self.content      = content
        self.root_comment = root_comment or self.id
        self.created_at   = created_at or now
        self.updated_at   = updated_at or now


    def _dt(self, value):
        return value.isoformat() if value else None

    def to_dict(self):
        return {
            "id":          self.id,
            "userId":      self.user_id,
            "userName":    self.user_name,
            "noteId":      self.note_id,
            "parentId":    self.parent_id,
            "rootComment": self.root_comment,
            "content":     self.content,
            "createdAt":   self._dt(self.created_at),
            "updatedAt":   self._dt(self.updated_at),
        }

    @staticmethod
    def from_dict(data):
        created = data.get("createdAt")
        updated = data.get("updatedAt")
        return Comment(
            id           = data.get("id"),
            user_id      = data["userId"],
            user_name    = data.get("userName"),
            note_id      = data["noteId"],
            parent_id    = data.get("parentId"),
            content      = data["content"],
            root_comment = data.get("rootComment"),
            created_at   = datetime.fromisoformat(created) if created else None,
            updated_at   = datetime.fromisoformat(updated) if updated else None,
        )
