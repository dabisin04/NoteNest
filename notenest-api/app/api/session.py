import traceback
from flask import Blueprint, request, jsonify
from app.config.db import db
from app.models.session import Session, SessionSchema
from datetime import datetime, timedelta
import uuid

ruta_session = Blueprint("route_session", __name__)

session_schema = SessionSchema()
sessions_schema = SessionSchema(many=True)

@ruta_session.route("/sessions", methods=["GET"])
def get_all_sessions():
    try:
        sessions = Session.query.all()
        result = sessions_schema.dump(sessions)
        return jsonify(result)
    except Exception as e:
        print(f"⚠️ Error in get_all_sessions: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Internal Server Error"}), 500

@ruta_session.route("/session/<string:user_id>", methods=["GET"])
def get_session_by_user(user_id):
    session = Session.query.get(user_id)
    if not session:
        return jsonify({"message": "Sesión no encontrada"}), 404
    return jsonify(session_schema.dump(session)), 200

@ruta_session.route("/createSession", methods=["POST"])
def create_session():
    try:
        data = request.json
        if not data.get("userId"):
            return jsonify({"error": "userId es requerido"}), 400

        # Verificar si ya existe una sesión para este usuario
        existing_session = Session.query.get(data["userId"])
        if existing_session:
            db.session.delete(existing_session)

        # Crear nueva sesión
        duration = timedelta(days=7)  # Duración por defecto
        if "duration" in data:
            duration = timedelta(days=data["duration"])

        new_session = Session(
            user_id=data["userId"],
            token=str(uuid.uuid4()),
            expires_at=datetime.utcnow() + duration
        )
        db.session.add(new_session)
        db.session.commit()

        return jsonify({
            "message": "Sesión creada correctamente",
            "session": session_schema.dump(new_session)
        }), 201

    except Exception as e:
        print(f"❌ Error en create_session: {str(e)}")
        print(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_session.route("/deleteSession/<string:user_id>", methods=["DELETE"])
def delete_session(user_id):
    try:
        session = Session.query.filter_by(user_id=user_id).first()
        if not session:
            return jsonify({"error": "Sesión no encontrada"}), 404
        db.session.delete(session)
        db.session.commit()
        return jsonify({"message": "Sesión eliminada"}), 200
    except Exception as e:
        print(f"❌ Error en delete_session: {str(e)}")
        print(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_session.route("/validateSession", methods=["POST"])
def validate_session():
    try:
        token = request.json.get("token")
        if not token:
            return jsonify({"error": "Token no proporcionado"}), 400

        session = Session.query.filter_by(token=token).first()
        if not session:
            return jsonify({"error": "Sesión no encontrada"}), 404

        if session.expires_at < datetime.utcnow():
            db.session.delete(session)
            db.session.commit()
            return jsonify({"error": "Sesión expirada"}), 401

        return jsonify({
            "message": "Sesión válida",
            "session": session_schema.dump(session)
        }), 200

    except Exception as e:
        print(f"❌ Error en validate_session: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500
