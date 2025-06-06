import traceback
import logging
from flask import Blueprint, request, jsonify, current_app
from app.config.db import db
from app.models.comment import Comment
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ruta_comment = Blueprint("route_comment", __name__)

@ruta_comment.route("/comments", methods=["GET"])
def get_all_comments():
    try:
        comments = Comment.query.all()
        return jsonify([c.to_dict() for c in comments])
    except Exception as e:
        logger.error("⚠️ Error in get_all_comments: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Internal Server Error"}), 500

@ruta_comment.route("/comment/<string:comment_id>", methods=["GET"])
def get_comment_by_id(comment_id):
    comment = Comment.query.get(comment_id)
    if not comment:
        return jsonify({"message": "Comentario no encontrado"}), 404
    return jsonify(comment.to_dict()), 200

@ruta_comment.route("/addComment", methods=["POST"])
def add_comment():
    try:
        data = request.json
        logger.info("📥 [addComment] Datos recibidos: %s", data)

        if not data.get("noteId") or not data.get("userId"):
            return jsonify({"error": "noteId y userId son requeridos"}), 400

        new_comment = Comment.from_dict(data)
        db.session.add(new_comment)
        db.session.flush()

        logger.info("✅ [addComment] Objeto en memoria: %s", new_comment.to_dict())

        db.session.commit()
        logger.info("💾 [addComment] Comentario guardado con ID: %s", new_comment.id)

        # Guardar en MongoDB
        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.insert_one({**new_comment.to_dict(), "from_flask": True})
            logger.info("📦 Comentario insertado en MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al insertar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Comentario guardado correctamente", "id": new_comment.id}), 201

    except Exception as e:
        logger.error("❌ Error en add_comment: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/replyComment", methods=["POST"])
def reply_comment():
    try:
        data = request.json
        logger.info("📥 [replyComment] Datos recibidos: %s", data)

        if not data.get("noteId") or not data.get("userId") or not data.get("parentId"):
            return jsonify({"error": "Faltan campos requeridos"}), 400

        parent = Comment.query.get(data["parentId"])
        if parent is None:
            return jsonify({"error": "Comentario padre no encontrado"}), 404

        # Establecer root_comment
        data["rootComment"] = parent.root_comment if parent.parent_id else parent.id

        new_reply = Comment.from_dict(data)
        db.session.add(new_reply)
        db.session.commit()
        logger.info("💾 [replyComment] Respuesta guardada con ID: %s", new_reply.id)

        # Guardar en MongoDB
        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.insert_one({**new_reply.to_dict(), "from_flask": True})
            logger.info("📦 Respuesta insertada en MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al insertar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Respuesta guardada", "id": new_reply.id}), 201

    except Exception as e:
        logger.error("❌ Error en reply_comment: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/deleteComment/<string:comment_id>", methods=["DELETE"])
def delete_comment(comment_id):
    try:
        comment = Comment.query.get(comment_id)
        if not comment:
            return jsonify({"error": "Comentario no encontrado"}), 404

        db.session.delete(comment)
        db.session.commit()

        try:
            mongo = current_app.config['MONGO_DB']
            mongo.comments.delete_one({"_id": comment_id})
            logger.info("🗑️ Comentario eliminado de MongoDB")
        except Exception as mongo_err:
            logger.error("❌ Error al eliminar en MongoDB: %s", str(mongo_err))

        return jsonify({"message": "Comentario eliminado"}), 200

    except Exception as e:
        logger.error("❌ Error en delete_comment: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/updateComment/<string:comment_id>", methods=["PUT"])
def update_comment(comment_id):
    try:
        comment = Comment.query.get(comment_id)
        if not comment:
            return jsonify({"error": "Comentario no encontrado"}), 404

        data = request.json
        if "content" in data:
            comment.content = data["content"]
        comment.updated_at = datetime.utcnow()

        db.session.commit()

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
        logger.error("❌ Error en update_comment: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/commentsByNote/<string:note_id>", methods=["GET"])
def get_comments_by_note(note_id):
    try:
        comments = Comment.query.filter_by(note_id=note_id).all()
        return jsonify([c.to_dict() for c in comments]), 200
    except Exception as e:
        logger.error("❌ Error en get_comments_by_note: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/commentsByUser/<string:user_id>", methods=["GET"])
def get_comments_by_user(user_id):
    try:
        comments = Comment.query.filter_by(user_id=user_id).all()
        return jsonify([c.to_dict() for c in comments]), 200
    except Exception as e:
        logger.error("❌ Error en get_comments_by_user: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/commentReplies/<string:comment_id>", methods=["GET"])
def get_comment_replies(comment_id):
    try:
        replies = Comment.query.filter_by(parent_id=comment_id).all()
        return jsonify([c.to_dict() for c in replies]), 200
    except Exception as e:
        logger.error("❌ Error en get_comment_replies: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500
