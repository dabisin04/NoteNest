import traceback
from flask import Blueprint, request, jsonify
from app.config.db import db
from app.models.comment import Comment
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ruta_comment = Blueprint("route_comment", __name__)

@ruta_comment.route("/comments", methods=["GET"])
def get_all_comments():
    try:
        comments = Comment.query.all()
        return jsonify([c.to_dict() for c in comments])
    except Exception as e:
        print(f"⚠️ Error in get_all_comments: {str(e)}")
        print(traceback.format_exc())
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
        db.session.flush()               # 🔑 ahora la BD le pone defaults

        logger.info("✅ [addComment] Objeto en memoria: %s", new_comment.to_dict())

        db.session.commit()
        logger.info("💾 [addComment] Comentario guardado con ID: %s", new_comment.id)

        return (
            jsonify({"message": "Comentario guardado correctamente", "id": new_comment.id}),
            201,
        )

    except Exception as e:
        logger.error("❌ Error en add_comment: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500


@ruta_comment.route("/replyComment", methods=["POST"])
def reply_comment():
    try:
        data = request.json
        logger.info("\ud83d\udce5 [replyComment] Datos recibidos: %s", data)

        if not data.get("noteId") or not data.get("userId") or not data.get("parentId"):
            return jsonify({"error": "Faltan campos requeridos"}), 400

        parent = Comment.query.get(data["parentId"])
        if parent is None:
            return jsonify({"error": "Comentario padre no encontrado"}), 404

        # Si el comentario padre ya es una respuesta, usamos su root_comment como raíz
        if parent.parent_id is not None:
            data["rootComment"] = parent.root_comment
        else:
            data["rootComment"] = parent.id

        new_reply = Comment.from_dict(data)
        logger.info("\u2705 [replyComment] Respuesta construida: %s", new_reply.to_dict())

        db.session.add(new_reply)
        db.session.commit()
        logger.info("\ud83d\udcc2 [replyComment] Respuesta guardada con ID: %s", new_reply.id)

        return jsonify({"message": "Respuesta guardada", "id": new_reply.id}), 201

    except Exception as e:
        logger.error("\u274c Error en reply_comment: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500


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
        return jsonify({"message": "Comentario eliminado"}), 200
    except Exception as e:
        print(f"❌ Error en delete_comment: {str(e)}")
        print(traceback.format_exc())
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
        return jsonify({"message": "Comentario actualizado correctamente"}), 200

    except Exception as e:
        print(f"❌ Error en update_comment: {str(e)}")
        print(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/commentsByNote/<string:note_id>", methods=["GET"])
def get_comments_by_note(note_id):
    try:
        comments = Comment.query.filter_by(note_id=note_id).all()
        return jsonify([c.to_dict() for c in comments]), 200
    except Exception as e:
        print(f"❌ Error en get_comments_by_note: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/commentsByUser/<string:user_id>", methods=["GET"])
def get_comments_by_user(user_id):
    try:
        comments = Comment.query.filter_by(user_id=user_id).all()
        return jsonify([c.to_dict() for c in comments]), 200
    except Exception as e:
        print(f"❌ Error en get_comments_by_user: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_comment.route("/commentReplies/<string:comment_id>", methods=["GET"])
def get_comment_replies(comment_id):
    try:
        replies = Comment.query.filter_by(parent_id=comment_id).all()
        return jsonify([c.to_dict() for c in replies]), 200
    except Exception as e:
        print(f"❌ Error en get_comment_replies: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500
