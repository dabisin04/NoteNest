import traceback
import uuid
import logging
from flask import Blueprint, request, jsonify, current_app
from app.config.db import db, mongo_db
from app.models.note import Note, NoteSchema
from app.models.note_files import NoteFile, NoteFileSchema
from app.models.user import User
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ruta_note = Blueprint("route_note", __name__)

note_schema = NoteSchema()
notes_schema = NoteSchema(many=True)
note_file_schema = NoteFileSchema(many=True)

@ruta_note.route("/notes", methods=["GET"])
def get_all_notes():
    try:
        logger.info("\U0001F4E5 Obteniendo todas las notas")
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
        logger.info("\U0001F4E5 Sincronizando notas: %s", notes_data)
        if not isinstance(notes_data, list):
            return jsonify({"error": "Se esperaba una lista de notas"}), 400

        mongo = current_app.config['MONGO_DB']
        for data in notes_data:
            note = Note.from_dict(data)
            db.session.merge(note)
            mongo.notes.update_one(
                {"_id": note.id}, {"$set": note.to_dict()}, upsert=True
            )
        db.session.commit()
        return jsonify({"message": "Notas sincronizadas correctamente"}), 201
    except Exception as e:
        logger.error(f"❌ Error en sync_notes: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno"}), 500

@ruta_note.route("/note/<string:note_id>", methods=["GET"])
def get_note_by_id(note_id):
    logger.info("\U0001F50D Buscando nota con ID: %s", note_id)
    note = Note.query.get(note_id)
    if not note:
        return jsonify({"message": "Nota no encontrada"}), 404
    return jsonify(note_schema.dump(note)), 200

@ruta_note.route("/addNote", methods=["POST"])
def add_note():
    try:
        data = request.json
        logger.info("\U0001F4DD Agregando nueva nota: %s", data)

        user_id = data.get("userId")
        if not user_id:
            return jsonify({"error": "La nota debe tener un userId válido"}), 400

        user = User.query.get(user_id)
        if not user:
            logger.warning("\u274C Usuario con ID %s no encontrado", user_id)
            return jsonify({"error": "El usuario no existe"}), 400

        files = data.pop('files', []) if isinstance(data.get('files'), list) else []
        new_note = Note.from_dict(data)
        db.session.add(new_note)

        note_files = []
        for file_data in files:
            if isinstance(file_data, dict) and 'fileUrl' in file_data:
                note_file = NoteFile(
                    id=file_data.get('id', str(uuid.uuid4())),
                    note_id=new_note.id,
                    file_url=file_data['fileUrl']
                )
                db.session.add(note_file)
                note_files.append(note_file.to_dict())

        db.session.commit()
        logger.info("✅ Nota agregada con ID: %s", new_note.id)

        mongo = current_app.config['MONGO_DB']
        mongo_note = new_note.to_dict()
        mongo_note["files"] = note_files
        mongo_note["from_flask"] = True
        mongo.notes.insert_one(mongo_note)
        
        # Guardar archivos en MongoDB también
        for file_data in note_files:
            mongo.note_files.insert_one({
                "_id": file_data["id"],
                "noteId": file_data["noteId"],
                "fileUrl": file_data["fileUrl"]
            })

        return jsonify({"message": "Nota guardada correctamente", "id": new_note.id}), 201

    except Exception as e:
        logger.error(f"❌ Error en add_note: {str(e)}")
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

        db.session.commit()

        # Actualizar en MongoDB
        mongo = current_app.config['MONGO_DB']
        mongo_note = note.to_dict()
        mongo.notes.update_one(
            {"_id": note.id},
            {"$set": mongo_note}
        )

        return jsonify({"message": "Nota actualizada correctamente"}), 200

    except Exception as e:
        logger.error(f"❌ Error en update_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/deleteNote/<string:note_id>", methods=["DELETE"])
def delete_note(note_id):
    try:
        logger.info("\U0001F5D1️ Eliminando nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        db.session.delete(note)
        db.session.commit()
        mongo_db.notes.delete_one({"_id": note_id})
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
        logger.error("❌ Error en get_notes_by_user: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500


@ruta_note.route("/publicNotes", methods=["GET"])
def get_public_notes():
    try:
        logger.info("🌐 Obteniendo notas públicas")
        notes = Note.query.filter_by(is_public=True).all()
        return jsonify(notes_schema.dump(notes)), 200
    except Exception as e:
        logger.error("❌ Error en get_public_notes: %s", str(e))
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

        # Actualizar en MongoDB
        mongo = current_app.config['MONGO_DB']
        result = mongo.notes.update_one(
            {"_id": note_id},
            {"$inc": {"likes": 1}}
        )
        
        if result.modified_count == 0:
            logger.warning("⚠️ No se actualizó el documento en MongoDB")
        
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
            
            # Actualizar en MongoDB
            mongo = current_app.config['MONGO_DB']
            result = mongo.notes.update_one(
                {"_id": note_id},
                {"$inc": {"likes": -1}}
            )
            
            if result.modified_count == 0:
                logger.warning("⚠️ No se actualizó el documento en MongoDB")
                
            return jsonify({"message": "Like eliminado", "likes": note.likes}), 200
        else:
            return jsonify({"message": "La nota no tiene likes para eliminar"}), 400

    except Exception as e:
        logger.error(f"❌ Error en unlike_note: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/noteFiles/<string:note_id>", methods=["GET"])
def get_note_files(note_id):
    try:
        logger.info("📎 Obteniendo archivos de la nota %s", note_id)
        
        # Verificar si la nota existe
        note = Note.query.get(note_id)
        if not note:
            logger.warning("⚠️ Nota no encontrada: %s", note_id)
            return jsonify({"error": "Nota no encontrada"}), 404

        # Obtener archivos de SQL
        note_files = NoteFile.query.filter_by(note_id=note_id).all()
        result = note_file_schema.dump(note_files)
        
        # Obtener archivos de MongoDB
        try:
            mongo = current_app.config['MONGO_DB']
            mongo_files = list(mongo.note_files.find({"noteId": note_id}))
            
            # Combinar resultados sin duplicados
            for mongo_file in mongo_files:
                if not any(f['id'] == str(mongo_file.get('_id')) for f in result):
                    result.append({
                        'id': str(mongo_file.get('_id')),
                        'noteId': mongo_file.get('noteId'),
                        'fileUrl': mongo_file.get('fileUrl')
                    })
            
            logger.info("✅ Archivos encontrados: %d", len(result))
        except Exception as mongo_error:
            logger.error("❌ Error al consultar MongoDB: %s", str(mongo_error))
            # Continuar con los resultados de SQL si MongoDB falla
            
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"❌ Error en get_note_files: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_note.route("/addNoteFile", methods=["POST"])
def add_note_file():
    try:
        data = request.json
        logger.info("📎 Agregando archivo a nota: %s", data)

        note_id = data.get("noteId")
        file_url = data.get("fileUrl")

        if not note_id or not file_url:
            return jsonify({"error": "Se requiere noteId y fileUrl"}), 400

        # Verificar si la nota existe
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        # Crear nuevo archivo
        file_id = data.get("id", str(uuid.uuid4()))
        note_file = NoteFile(
            id=file_id,
            note_id=note_id,
            file_url=file_url
        )

        db.session.add(note_file)
        db.session.commit()

        # Guardar en MongoDB
        mongo = current_app.config['MONGO_DB']
        mongo_file = {
            "_id": file_id,
            "noteId": note_id,
            "fileUrl": file_url
        }
        mongo.note_files.insert_one(mongo_file)

        return jsonify({
            "message": "Archivo agregado correctamente",
            "id": file_id
        }), 201

    except Exception as e:
        logger.error(f"❌ Error en add_note_file: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
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

        # Eliminar de MongoDB
        mongo = current_app.config['MONGO_DB']
        mongo.note_files.delete_one({"_id": file_id})

        return jsonify({"message": "Archivo eliminado correctamente"}), 200

    except Exception as e:
        logger.error(f"❌ Error en delete_note_file: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500
