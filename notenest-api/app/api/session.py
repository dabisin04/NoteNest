# Este archivo maneja las sesiones de usuario en la aplicación
# Una sesión representa el período de tiempo en que un usuario está activo/conectado

import traceback
from flask import Blueprint, request, jsonify, current_app
from app.config.db import db
from app.models.session import Session, SessionSchema
from datetime import datetime, timedelta
import uuid

# Crear un Blueprint de Flask para las rutas de sesión
ruta_session = Blueprint("route_session", __name__)

# Esquemas para convertir objetos Sesión a formato JSON y viceversa
session_schema = SessionSchema()
sessions_schema = SessionSchema(many=True)

# Ruta para obtener todas las sesiones activas
@ruta_session.route("/sessions", methods=["GET"])
def get_all_sessions():
    """
    Obtiene una lista de todas las sesiones activas en el sistema
    Útil para monitoreo y administración
    """
    try:
        sessions = Session.query.all()
        result = sessions_schema.dump(sessions)
        return jsonify(result)
    except Exception as e:
        print(f"⚠️ Error al obtener sesiones: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para obtener la sesión de un usuario específico
@ruta_session.route("/session/<string:user_id>", methods=["GET"])
def get_session_by_user(user_id):
    """
    Busca y retorna la sesión activa de un usuario específico
    Parámetros:
        user_id: ID del usuario cuya sesión se busca
    """
    session = Session.query.get(user_id)
    if not session:
        return jsonify({"message": "Sesión no encontrada"}), 404
    return jsonify(session_schema.dump(session)), 200

# Ruta para crear una nueva sesión
@ruta_session.route("/createSession", methods=["POST"])
def create_session():
    """
    Crea una nueva sesión para un usuario
    Requiere: ID del usuario (userId)
    Opcional: duración de la sesión en días
    Guarda la sesión tanto en MySQL como en MongoDB
    """
    try:
        data = request.json
        if not data.get("userId"):
            return jsonify({"error": "userId es requerido"}), 400

        # Si existe una sesión anterior, la eliminamos
        existing_session = Session.query.filter_by(user_id=data["userId"]).first()
        if existing_session:
            db.session.delete(existing_session)

        # Configurar duración de la sesión (por defecto 7 días)
        duration = timedelta(days=7)
        if "duration" in data:
            duration = timedelta(days=data["duration"])

        # Crear nueva sesión con token único
        new_session = Session(
            user_id=data["userId"],
            token=str(uuid.uuid4()),
            expires_at=datetime.utcnow() + duration
        )

        # Guardar en base de datos SQL
        db.session.add(new_session)
        db.session.commit()
        print("✅ Sesión guardada en MySQL")

        # Guardar también en MongoDB para sincronización
        mongo = current_app.config['MONGO_DB']
        mongo.sessions.insert_one(new_session.to_dict())
        print("✅ Sesión guardada en MongoDB")

        return jsonify({
            "message": "Sesión creada correctamente",
            "session": session_schema.dump(new_session)
        }), 201

    except Exception as e:
        print(f"❌ Error al crear sesión: {str(e)}")
        print(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para eliminar una sesión
@ruta_session.route("/deleteSession/<string:user_id>", methods=["DELETE"])
def delete_session(user_id):
    """
    Elimina la sesión de un usuario
    Útil para cerrar sesión o forzar el cierre de sesión por seguridad
    """
    try:
        session = Session.query.filter_by(user_id=user_id).first()
        if not session:
            return jsonify({"error": "Sesión no encontrada"}), 404
        db.session.delete(session)
        db.session.commit()
        return jsonify({"message": "Sesión eliminada"}), 200
    except Exception as e:
        print(f"❌ Error al eliminar sesión: {str(e)}")
        print(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500

# Ruta para validar una sesión
@ruta_session.route("/validateSession", methods=["POST"])
def validate_session():
    """
    Verifica si una sesión es válida y no ha expirado
    Requiere: token de sesión
    Retorna: estado de la sesión y datos asociados
    """
    try:
        token = request.json.get("token")
        if not token:
            return jsonify({"error": "Token no proporcionado"}), 400

        # Buscar la sesión por el token
        session = Session.query.filter_by(token=token).first()
        if not session:
            return jsonify({"error": "Sesión no encontrada"}), 404

        # Verificar si la sesión ha expirado
        if session.expires_at < datetime.utcnow():
            # Si expiró, eliminar la sesión
            db.session.delete(session)
            db.session.commit()
            return jsonify({"error": "Sesión expirada"}), 401

        return jsonify({
            "message": "Sesión válida",
            "session": session_schema.dump(session)
        }), 200

    except Exception as e:
        print(f"❌ Error al validar sesión: {str(e)}")
        print(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500
