# Este archivo maneja todas las operaciones relacionadas con comentarios en las notas
# (crear, leer, actualizar, eliminar comentarios y respuestas a comentarios)

import traceback
import logging
from flask import Blueprint, request, jsonify, current_app
from app.config.db import db
from app.models.comment import Comment
from datetime import datetime

# Configuración del sistema de registro para seguimiento de eventos y errores
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Crear un Blueprint de Flask para las rutas de comentarios
ruta_comment = Blueprint("route_comment", __name__)

# Ruta para obtener todos los comentarios
@ruta_comment.route("/comments", methods=["GET"])
def get_all_comments():
    """
    Obtiene una lista de todos los comentarios en el sistema
    Útil para administración y moderación de comentarios
    """
    try:
        comments = Comment.query.all()
        return jsonify([c.to_dict() for c in comments])
    except Exception as e:
        logger.error("⚠️ Error al obtener comentarios: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener un comentario específico
@ruta_comment.route("/comment/<string:comment_id>", methods=["GET"])
def get_comment_by_id(comment_id):
    """
    Busca y retorna un comentario específico por su ID
    Parámetros:
        comment_id: ID del comentario a buscar
    """
    comment = Comment.query.get(comment_id)
    if not comment:
        return jsonify({"message": "Comentario no encontrado"}), 404
    return jsonify(comment.to_dict()), 200

# Ruta para agregar un nuevo comentario
@ruta_comment.route("/addComment", methods=["POST"])
def add_comment():
    """
    Crea un nuevo comentario en una nota
    Requiere: ID de la nota (noteId) y ID del usuario (userId)
    Guarda el comentario tanto en MySQL como en MongoDB
    """
    try:
        data = request.json
        logger.info("📥 [addComment] Datos recibidos: %s", data)

        # Verificar campos requeridos
        if not data.get("noteId") or not data.get("userId"):
            return jsonify({"error": "noteId y userId son requeridos"}), 400

        # Crear y guardar el nuevo comentario
        new_comment = Comment.from_dict(data)
        db.session.add(new_comment)
        db.session.flush()

        logger.info("✅ [addComment] Objeto en memoria: %s", new_comment.to_dict())

        db.session.commit()
        logger.info("💾 [addComment] Comentario guardado con ID: %s", new_comment.id)

        # Guardar en MongoDB para sincronización
        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.insert_one({**new_comment.to_dict(), "from_flask": True})
            logger.info("📦 Comentario insertado en MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al insertar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Comentario guardado correctamente", "id": new_comment.id}), 201

    except Exception as e:
        logger.error("❌ Error al crear comentario: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para responder a un comentario existente
@ruta_comment.route("/replyComment", methods=["POST"])
def reply_comment():
    """
    Crea una respuesta a un comentario existente
    Requiere: ID de la nota, ID del usuario y ID del comentario padre
    Mantiene una estructura jerárquica de comentarios
    """
    try:
        data = request.json
        logger.info("📥 [replyComment] Datos recibidos: %s", data)

        # Verificar campos requeridos
        if not data.get("noteId") or not data.get("userId") or not data.get("parentId"):
            return jsonify({"error": "Faltan campos requeridos"}), 400

        # Verificar que existe el comentario padre
        parent = Comment.query.get(data["parentId"])
        if parent is None:
            return jsonify({"error": "Comentario padre no encontrado"}), 404

        # Establecer el comentario raíz (para mantener la jerarquía)
        data["rootComment"] = parent.root_comment if parent.parent_id else parent.id

        # Crear y guardar la respuesta
        new_reply = Comment.from_dict(data)
        db.session.add(new_reply)
        db.session.commit()
        logger.info("💾 [replyComment] Respuesta guardada con ID: %s", new_reply.id)

        # Guardar en MongoDB para sincronización
        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.insert_one({**new_reply.to_dict(), "from_flask": True})
            logger.info("📦 Respuesta insertada en MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al insertar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Respuesta guardada", "id": new_reply.id}), 201

    except Exception as e:
        logger.error("❌ Error al crear respuesta: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para eliminar un comentario
@ruta_comment.route("/deleteComment/<string:comment_id>", methods=["DELETE"])
def delete_comment(comment_id):
    """
    Elimina un comentario específico
    Parámetros:
        comment_id: ID del comentario a eliminar
    Elimina el comentario de ambas bases de datos
    """
    try:
        comment = Comment.query.get(comment_id)
        if not comment:
            return jsonify({"error": "Comentario no encontrado"}), 404

        db.session.delete(comment)
        db.session.commit()

        # Eliminar también de MongoDB
        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.delete_one({"_id": comment_id})
            logger.info("🗑️ Comentario eliminado de MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al eliminar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Comentario eliminado"}), 200

    except Exception as e:
        logger.error("❌ Error al eliminar comentario: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para actualizar un comentario
@ruta_comment.route("/updateComment/<string:comment_id>", methods=["PUT"])
def update_comment(comment_id):
    """
    Actualiza el contenido de un comentario existente
    Parámetros:
        comment_id: ID del comentario a actualizar
    Actualiza el comentario en ambas bases de datos
    """
    try:
        comment = Comment.query.get(comment_id)
        if not comment:
            return jsonify({"error": "Comentario no encontrado"}), 404

        data = request.json
        # Actualizar el contenido si está presente en la petición
        if "content" in data:
            comment.content = data["content"]
        comment.updated_at = datetime.utcnow()

        db.session.commit()

        # Actualizar en MongoDB para mantener sincronización
        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.update_one(
                {"_id": comment_id},
                {"$set": {
                    "content": comment.content,
                    "updatedAt": comment.updated_at.isoformat()
                }}
            )
            logger.info("✏️ Comentario actualizado también en MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al actualizar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Comentario actualizado correctamente"}), 200

    except Exception as e:
        logger.error("❌ Error al actualizar comentario: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener comentarios de una nota específica
@ruta_comment.route("/commentsByNote/<string:note_id>", methods=["GET"])
def get_comments_by_note(note_id):
    """
    Obtiene todos los comentarios asociados a una nota específica
    Parámetros:
        note_id: ID de la nota cuyos comentarios se quieren obtener
    """
    try:
        comments = Comment.query.filter_by(note_id=note_id).all()
        return jsonify([c.to_dict() for c in comments]), 200
    except Exception as e:
        logger.error("❌ Error al obtener comentarios de la nota: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener comentarios de un usuario específico
@ruta_comment.route("/commentsByUser/<string:user_id>", methods=["GET"])
def get_comments_by_user(user_id):
    """
    Obtiene todos los comentarios realizados por un usuario específico
    Parámetros:
        user_id: ID del usuario cuyos comentarios se quieren obtener
    """
    try:
        comments = Comment.query.filter_by(user_id=user_id).all()
        return jsonify([c.to_dict() for c in comments]), 200
    except Exception as e:
        logger.error("❌ Error al obtener comentarios del usuario: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener las respuestas a un comentario
@ruta_comment.route("/commentReplies/<string:comment_id>", methods=["GET"])
def get_comment_replies(comment_id):
    """
    Obtiene todas las respuestas a un comentario específico
    Parámetros:
        comment_id: ID del comentario del cual se quieren obtener las respuestas
    """
    try:
        replies = Comment.query.filter_by(parent_id=comment_id).all()
        return jsonify([c.to_dict() for c in replies]), 200
    except Exception as e:
        logger.error("❌ Error al obtener respuestas del comentario: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500
