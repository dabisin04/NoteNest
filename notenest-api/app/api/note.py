# Este archivo maneja todas las operaciones relacionadas con notas en la aplicación
# (crear, leer, actualizar, eliminar notas, gestionar archivos adjuntos, likes, etc.)

import traceback
import uuid
import logging
from flask import Blueprint, request, jsonify, current_app
from app.config.db import db, mongo_db
from app.models.note import Note, NoteSchema
from app.models.note_files import NoteFile, NoteFileSchema
from app.models.user import User
from datetime import datetime

# Configuración del sistema de registro para seguimiento de eventos y errores
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Crear un Blueprint de Flask para las rutas de notas
ruta_note = Blueprint("route_note", __name__)

# Esquemas para convertir objetos Nota y archivos adjuntos a formato JSON y viceversa
note_schema = NoteSchema()
notes_schema = NoteSchema(many=True)
note_file_schema = NoteFileSchema(many=True)

# Ruta para obtener todas las notas
@ruta_note.route("/notes", methods=["GET"])
def get_all_notes():
    """
    Obtiene una lista de todas las notas en el sistema
    Retorna: Lista de notas en formato JSON
    """
    try:
        logger.info("\U0001F4E5 Obteniendo todas las notas")
        notes = Note.query.all()
        result = notes_schema.dump(notes)
        return jsonify(result)
    except Exception as e:
        logger.error(f"⚠️ Error al obtener notas: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para sincronizar notas entre bases de datos
@ruta_note.route("/notes", methods=["POST"])
def sync_notes():
    """
    Sincroniza las notas entre MySQL y MongoDB
    Recibe: Lista de notas para sincronizar
    Actualiza o crea notas en ambas bases de datos
    """
    try:
        notes_data = request.json
        logger.info("\U0001F4E5 Sincronizando notas: %s", notes_data)
        if not isinstance(notes_data, list):
            return jsonify({"error": "Se esperaba una lista de notas"}), 400

        # Sincronizar cada nota en ambas bases de datos
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
        logger.error(f"❌ Error en sincronización de notas: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno"}), 500

# Ruta para obtener una nota específica
@ruta_note.route("/note/<string:note_id>", methods=["GET"])
def get_note_by_id(note_id):
    """
    Busca y retorna una nota específica por su ID
    Parámetros:
        note_id: ID de la nota a buscar
    """
    logger.info("\U0001F50D Buscando nota con ID: %s", note_id)
    note = Note.query.get(note_id)
    if not note:
        return jsonify({"message": "Nota no encontrada"}), 404
    return jsonify(note_schema.dump(note)), 200

# Ruta para crear una nueva nota
@ruta_note.route("/addNote", methods=["POST"])
def add_note():
    """
    Crea una nueva nota con sus archivos adjuntos
    Requiere: datos de la nota y opcionalmente archivos adjuntos
    Guarda la nota y sus archivos tanto en MySQL como en MongoDB
    """
    try:
        data = request.json
        logger.info("\U0001F4DD Agregando nueva nota: %s", data)

        # Verificar que el usuario existe
        user_id = data.get("userId")
        if not user_id:
            return jsonify({"error": "La nota debe tener un userId válido"}), 400

        user = User.query.get(user_id)
        if not user:
            logger.warning("\u274C Usuario con ID %s no encontrado", user_id)
            return jsonify({"error": "El usuario no existe"}), 400

        # Separar los archivos adjuntos de los datos de la nota
        files = data.pop('files', []) if isinstance(data.get('files'), list) else []
        new_note = Note.from_dict(data)
        db.session.add(new_note)

        # Procesar y guardar los archivos adjuntos
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

        # Guardar en MongoDB para sincronización
        mongo = current_app.config['MONGO_DB']
        mongo_note = new_note.to_dict()
        mongo_note["files"] = note_files
        mongo_note["from_flask"] = True
        mongo.notes.insert_one(mongo_note)
        
        # Guardar archivos adjuntos en MongoDB
        for file_data in note_files:
            mongo.note_files.insert_one({
                "_id": file_data["id"],
                "noteId": file_data["noteId"],
                "fileUrl": file_data["fileUrl"]
            })

        return jsonify({"message": "Nota guardada correctamente", "id": new_note.id}), 201

    except Exception as e:
        logger.error(f"❌ Error al crear nota: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para actualizar una nota existente
@ruta_note.route("/updateNote/<string:note_id>", methods=["PUT"])
def update_note(note_id):
    """
    Actualiza una nota existente
    Parámetros:
        note_id: ID de la nota a actualizar
    Permite actualizar: título, contenido y estado público/privado
    """
    try:
        logger.info("✏️ Actualizando nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        data = request.json
        # Actualizar campos si están presentes en la petición
        if "title" in data:
            note.title = data["title"]
        if "content" in data:
            note.content = data["content"]
        if "isPublic" in data:
            note.is_public = data["isPublic"]
        note.updated_at = datetime.utcnow()

        db.session.commit()

        # Actualizar en MongoDB para mantener sincronización
        mongo = current_app.config['MONGO_DB']
        mongo_note = note.to_dict()
        mongo.notes.update_one(
            {"_id": note.id},
            {"$set": mongo_note}
        )

        return jsonify({"message": "Nota actualizada correctamente"}), 200

    except Exception as e:
        logger.error(f"❌ Error al actualizar nota: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para eliminar una nota
@ruta_note.route("/deleteNote/<string:note_id>", methods=["DELETE"])
def delete_note(note_id):
    """
    Elimina una nota y sus archivos adjuntos
    Parámetros:
        note_id: ID de la nota a eliminar
    Elimina la nota de ambas bases de datos
    """
    try:
        logger.info("\U0001F5D1️ Eliminando nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        db.session.delete(note)
        db.session.commit()
        
        # Eliminar también de MongoDB
        mongo = current_app.config['MONGO_DB']
        mongo.notes.delete_one({"_id": note_id})
        return jsonify({"message": "Nota eliminada"}), 200
    except Exception as e:
        logger.error(f"❌ Error al eliminar nota: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener notas de un usuario específico
@ruta_note.route("/notesByUser/<string:user_id>", methods=["GET"])
def get_notes_by_user(user_id):
    """
    Obtiene todas las notas de un usuario específico
    Parámetros:
        user_id: ID del usuario cuyas notas se quieren obtener
    """
    try:
        logger.info("📄 Obteniendo notas del usuario %s", user_id)
        notes = Note.query.filter_by(user_id=user_id).all()
        return jsonify(notes_schema.dump(notes)), 200
    except Exception as e:
        logger.error("❌ Error al obtener notas del usuario: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener notas públicas
@ruta_note.route("/publicNotes", methods=["GET"])
def get_public_notes():
    """
    Obtiene todas las notas marcadas como públicas
    Útil para la sección de notas públicas/compartidas
    """
    try:
        logger.info("🌐 Obteniendo notas públicas")
        notes = Note.query.filter_by(is_public=True).all()
        return jsonify(notes_schema.dump(notes)), 200
    except Exception as e:
        logger.error("❌ Error al obtener notas públicas: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para dar "me gusta" a una nota
@ruta_note.route("/likeNote/<string:note_id>", methods=["PUT"])
def like_note(note_id):
    """
    Incrementa el contador de "me gusta" de una nota
    Parámetros:
        note_id: ID de la nota a la que se dará like
    Actualiza el contador en ambas bases de datos
    """
    try:
        logger.info("👍 Añadiendo like a la nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        note.likes += 1
        db.session.commit()

        # Actualizar likes en MongoDB
        mongo = current_app.config['MONGO_DB']
        result = mongo.notes.update_one(
            {"_id": note_id},
            {"$inc": {"likes": 1}}
        )
        
        if result.modified_count == 0:
            logger.warning("⚠️ No se actualizó el documento en MongoDB")
        
        return jsonify({"message": "Like añadido", "likes": note.likes}), 200

    except Exception as e:
        logger.error(f"❌ Error al dar like: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para quitar "me gusta" de una nota
@ruta_note.route("/unlikeNote/<string:note_id>", methods=["PUT"])
def unlike_note(note_id):
    """
    Decrementa el contador de "me gusta" de una nota
    Parámetros:
        note_id: ID de la nota a la que se quitará el like
    Solo reduce el contador si es mayor que 0
    """
    try:
        logger.info("👎 Eliminando like de la nota %s", note_id)
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        if note.likes > 0:
            note.likes -= 1
            db.session.commit()
            
            # Actualizar likes en MongoDB
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
        logger.error(f"❌ Error al quitar like: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener los archivos adjuntos de una nota
@ruta_note.route("/noteFiles/<string:note_id>", methods=["GET"])
def get_note_files(note_id):
    """
    Obtiene todos los archivos adjuntos de una nota específica
    Parámetros:
        note_id: ID de la nota cuyos archivos se quieren obtener
    Combina resultados de MySQL y MongoDB
    """
    try:
        logger.info("📎 Obteniendo archivos de la nota %s", note_id)
        
        # Verificar que la nota existe
        note = Note.query.get(note_id)
        if not note:
            logger.warning("⚠️ Nota no encontrada: %s", note_id)
            return jsonify({"error": "Nota no encontrada"}), 404

        # Obtener archivos de MySQL
        note_files = NoteFile.query.filter_by(note_id=note_id).all()
        result = note_file_schema.dump(note_files)
        
        # Obtener y combinar archivos de MongoDB
        try:
            mongo = current_app.config['MONGO_DB']
            mongo_files = list(mongo.note_files.find({"noteId": note_id}))
            
            # Combinar resultados evitando duplicados
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
            
        return jsonify(result), 200
        
    except Exception as e:
        logger.error(f"❌ Error al obtener archivos: {str(e)}")
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para agregar un archivo adjunto a una nota
@ruta_note.route("/addNoteFile", methods=["POST"])
def add_note_file():
    """
    Agrega un nuevo archivo adjunto a una nota
    Requiere: ID de la nota y URL del archivo
    Guarda el archivo en ambas bases de datos
    """
    try:
        data = request.json
        logger.info("📎 Agregando archivo a nota: %s", data)

        note_id = data.get("noteId")
        file_url = data.get("fileUrl")

        if not note_id or not file_url:
            return jsonify({"error": "Se requiere noteId y fileUrl"}), 400

        # Verificar que la nota existe
        note = Note.query.get(note_id)
        if not note:
            return jsonify({"error": "Nota no encontrada"}), 404

        # Crear nuevo archivo adjunto
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
        logger.error(f"❌ Error al agregar archivo: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para eliminar un archivo adjunto
@ruta_note.route("/deleteNoteFile/<string:file_id>", methods=["DELETE"])
def delete_note_file(file_id):
    """
    Elimina un archivo adjunto de una nota
    Parámetros:
        file_id: ID del archivo a eliminar
    Elimina el archivo de ambas bases de datos
    """
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
        logger.error(f"❌ Error al eliminar archivo: {str(e)}")
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500
