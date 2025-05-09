import traceback
import uuid
from flask import Blueprint, request, jsonify
from app.config.db import db
from app.models.note import Note, NoteSchema
from app.models.note_files import NoteFile
from app.models.user import User
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ruta_note = Blueprint("route_note", __name__)

note_schema = NoteSchema()
notes_schema = NoteSchema(many=True)

@ruta_note.route("/notes", methods=["GET"])
def get_all_notes():
    try:
        logger.info("📥 Obteniendo todas las notas")
        notes = Note.query.all()
        result = notes_schema.dump(notes)
        return jsonify(result)
    except Exception as e:
        logger.error(f"⚠️ Error in get_all_notes: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Internal Server Error"}), 500

@ruta_note.route("/notes", methods=["POST"])
def sync_notes():
    try:
        notes_data = request.json
        logger.info("📥 Sincronizando notas: %s", notes_data)
        if not isinstance(notes_data, list):
            return jsonify({"error": "Se esperaba una lista de notas"}), 400

        for data in notes_data:
            note = Note.from_dict(data)
            db.session.merge(note)
        db.session.commit()
        return jsonify({"message": "Notas sincronizadas correctamente"}), 201
    except Exception as e:
        logger.error(f"❌ Error en sync_notes: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno"}), 500

@ruta_note.route("/note/<string:note_id>", methods=["GET"])
def get_note_by_id(note_id):
    logger.info("🔍 Buscando nota con ID: %s", note_id)
    note = Note.query.get(note_id)
    if not note:
        return jsonify({"message": "Nota no encontrada"}), 404
    return jsonify(note_schema.dump(note)), 200

@ruta_note.route("/addNote", methods=["POST"])
def add_note():
    try:
        data = request.json
        logger.info("📝 Agregando nueva nota: %s", data)

        user_id = data.get("userId")
        if not user_id:
            return jsonify({"error": "La nota debe tener un userId válido"}), 400

        # Verificar existencia del usuario
        user = User.query.get(user_id)
        if not user:
            logger.warning("🚫 Usuario con ID %s no encontrado", user_id)
            return jsonify({"error": "El usuario no existe"}), 400

        # Extraer archivos antes de crear la nota
        files = data.pop('files', []) if isinstance(data.get('files'), list) else []
        
        new_note = Note.from_dict(data)
        db.session.add(new_note)

        # Procesar archivos
        for file_data in files:
            if isinstance(file_data, dict) and 'fileUrl' in file_data:
                note_file = NoteFile(
                    id=str(uuid.uuid4()),
                    note_id=new_note.id,
                    file_url=file_data['fileUrl']
                )
                db.session.add(note_file)
                logger.info("📎 Archivo agregado: %s", file_data['fileUrl'])

        db.session.commit()
        logger.info("✅ Nota agregada con ID: %s", new_note.id)
        return jsonify({"message": "Nota guardada correctamente", "id": new_note.id}), 201

    except Exception as e:
        logger.error(f"❌ Error en add_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/addNoteFile", methods=["POST"])
def add_note_file():
    try:
        data = request.json
        logger.info("📎 Agregando archivo a nota: %s", data)
        note_id = data.get("noteId")
        file_url = data.get("fileUrl")

        if not note_id or not file_url:
            return jsonify({"error": "Faltan campos obligatorios"}), 400

        note_file = NoteFile(
            id=str(uuid.uuid4()),
            note_id=note_id,
            file_url=file_url
        )

        db.session.add(note_file)
        db.session.commit()
        logger.info("✅ Archivo agregado a nota %s: %s", note_id, file_url)
        return jsonify({"message": "Archivo asociado a la nota exitosamente"}), 201

    except Exception as e:
        logger.error(f"❌ Error en add_note_file: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/noteFiles/<string:note_id>", methods=["GET"])
def get_note_files(note_id):
    try:
        logger.info("📂 Obteniendo archivos para la nota %s", note_id)
        files = NoteFile.query.filter_by(note_id=note_id).all()
        return jsonify([file.to_dict() for file in files]), 200
    except Exception as e:
        logger.error(f"❌ Error en get_note_files: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/deleteNoteFile/<string:file_id>", methods=["DELETE"])
def delete_note_file(file_id):
    try:
        logger.info("🗑️ Eliminando archivo %s", file_id)
        note_file = NoteFile.query.get(file_id)
        if not note_file:
            return jsonify({"error": "Archivo no encontrado"}), 404

        db.session.delete(note_file)
        db.session.commit()
        return jsonify({"message": "Archivo eliminado"}), 200
    except Exception as e:
        logger.error(f"❌ Error en delete_note_file: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/updateNote/<string:note_id>", methods=["PUT"])
def update_note(note_id):
    try:
        logger.info("✏️ Actualizando nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        data = request.json

        if "title" in data:
            note.title = data["title"]
        if "content" in data:
            note.content = data["content"]
        if "isPublic" in data:
            note.is_public = data["isPublic"]
        note.updated_at = datetime.utcnow()

        if "files" in data and isinstance(data["files"], list):
            for file in data["files"]:
                note_file = NoteFile(
                    id=str(uuid.uuid4()),
                    note_id=note.id,
                    file_url=file.get("fileUrl")
                )
                db.session.add(note_file)

        db.session.commit()
        return jsonify({"message": "Nota actualizada correctamente"}), 200

    except Exception as e:
        logger.error(f"❌ Error en update_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/deleteNote/<string:note_id>", methods=["DELETE"])
def delete_note(note_id):
    try:
        logger.info("🗑️ Eliminando nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404
        db.session.delete(note)
        db.session.commit()
        return jsonify({"message": "Nota eliminada"}), 200
    except Exception as e:
        logger.error(f"❌ Error en delete_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/notesByUser/<string:user_id>", methods=["GET"])
def get_notes_by_user(user_id):
    try:
        logger.info("📄 Obteniendo notas del usuario %s", user_id)
        notes = Note.query.filter_by(user_id=user_id).all()
        return jsonify(notes_schema.dump(notes)), 200
    except Exception as e:
        logger.error(f"❌ Error en get_notes_by_user: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/publicNotes", methods=["GET"])
def get_public_notes():
    try:
        logger.info("🌐 Obteniendo notas públicas")
        notes = Note.query.filter_by(is_public=True).all()
        return jsonify(notes_schema.dump(notes)), 200
    except Exception as e:
        logger.error(f"❌ Error en get_public_notes: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/likeNote/<string:note_id>", methods=["PUT"])
def like_note(note_id):
    try:
        logger.info("👍 Añadiendo like a la nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        note.likes += 1
        db.session.commit()
        return jsonify({"message": "Like añadido", "likes": note.likes}), 200

    except Exception as e:
        logger.error(f"❌ Error en like_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/unlikeNote/<string:note_id>", methods=["PUT"])
def unlike_note(note_id):
    try:
        logger.info("👎 Eliminando like de la nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        if note.likes > 0:
            note.likes -= 1
            db.session.commit()
            return jsonify({"message": "Like eliminado", "likes": note.likes}), 200
        else:
            return jsonify({"message": "La nota no tiene likes para eliminar"}), 400

    except Exception as e:
        logger.error(f"❌ Error en unlike_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/searchNotes", methods=["GET"])
def search_notes():
    try:
        query = request.args.get("query", "")
        logger.info("🔎 Buscando notas con texto: %s", query)
        notes = Note.query.filter(
            Note.title.ilike(f"%{query}%") | Note.content.ilike(f"%{query}%")
        ).all()
        return jsonify(notes_schema.dump(notes)), 200
    except Exception as e:
        logger.error(f"❌ Error en search_notes: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500
