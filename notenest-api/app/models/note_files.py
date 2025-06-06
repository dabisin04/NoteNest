from app.config.db import db
from marshmallow import Schema, fields
import uuid

class NoteFile(db.Model):
    __tablename__ = 'note_files'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    note_id = db.Column(db.String(36), db.ForeignKey('notes.id', ondelete='CASCADE'), nullable=False)
    file_url = db.Column(db.String(255), nullable=False)

    # Relación inversa opcional
    note = db.relationship('Note', backref=db.backref('files', cascade='all, delete-orphan', lazy=True))

    def __init__(self, id=None, note_id=None, file_url=None):
        self.id = id or str(uuid.uuid4())
        self.note_id = note_id
        self.file_url = file_url

    def to_dict(self):
        return {
            '_id': self.id,  # Para MongoDB
            'id': self.id,
            'noteId': self.note_id,
            'fileUrl': self.file_url
        }

    @staticmethod
    def from_dict(data):
        return NoteFile(
            id=data.get('id') or data.get('_id'),
            note_id=data['noteId'],
            file_url=data['fileUrl']
        )
class NoteFileSchema(Schema):
    id = fields.Str()
    noteId = fields.Str(attribute='note_id')
    fileUrl = fields.Str(attribute='file_url')
