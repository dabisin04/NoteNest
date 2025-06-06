import logging
import traceback
from flask import Blueprint, request, jsonify, current_app
from app.config.db import db
from app.models.user import User, UserSchema
from app.utils.password_utils import hash_password, verify_password, generate_uuid
from datetime import datetime

# Configuración del logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ruta_user = Blueprint("route_user", __name__)

user_schema = UserSchema()
users_schema = UserSchema(many=True)

@ruta_user.route("/users", methods=["GET"])
def get_all_users():
    try:
        users = User.query.all()
        result = users_schema.dump(users)
        return jsonify(result)
    except Exception as e:
        logger.error("⚠️ Error in get_all_users: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Internal Server Error"}), 500

@ruta_user.route("/user/<string:user_id>", methods=["GET"])
def get_user_by_id(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({"message": "Usuario no encontrado"}), 404
    return jsonify(user_schema.dump(user)), 200

@ruta_user.route("/register", methods=["POST"])
def register_user():
    try:
        data = request.json
        logger.info("📥 Datos recibidos en /register: %s", data)

        if not data.get("email") or not data.get("name") or not data.get("password"):
            logger.warning("❌ Faltan campos obligatorios")
            return jsonify({"error": "Email, nombre y contraseña son requeridos"}), 400

        existing_user = User.query.filter_by(email=data["email"]).first()
        logger.info("🔍 Usuario existente: %s", existing_user)

        if existing_user:
            logger.warning("❌ El email ya está registrado")
            return jsonify({"error": "El email ya está registrado"}), 409

        user_id = generate_uuid()
        logger.info("🆔 UUID generado: %s", user_id)

        hashed_password, salt = hash_password(data["password"])
        logger.info("🔐 Hash generado y 🧂 Salt generado correctamente")

        # Crear usuario SQL
        new_user = User(
            id=user_id,
            email=data["email"],
            name=data["name"],
            password_hash=hashed_password,
            salt=salt,
            created_at=datetime.utcnow()
        )
        logger.info("📦 Usuario preparado para insertar en MySQL: %s", new_user.to_dict())

        db.session.add(new_user)
        db.session.commit()
        logger.info("✅ Usuario insertado correctamente en MySQL")

        # Insertar también en MongoDB
        try:
            mongo = current_app.config['MONGO_DB']
            mongo_user = {
                "_id": user_id,  # UUID como clave primaria en Mongo
                "id": user_id,
                "email": data["email"],
                "name": data["name"],
                "passwordHash": hashed_password.decode(),
                "salt": salt.decode(),
                "token": None,
                "createdAt": datetime.utcnow().isoformat(),
                "updatedAt": datetime.utcnow().isoformat(),
                "from_flask": True
            }
            mongo.users.insert_one(mongo_user)
            logger.info("✅ Usuario insertado correctamente en MongoDB")
        except Exception as mongo_error:
            logger.error("❌ Error al insertar en MongoDB: %s", str(mongo_error))
            logger.debug(traceback.format_exc())

        return jsonify({
            "message": "Usuario registrado correctamente",
            "id": new_user.id,
            "salt": salt.decode(),
            "passwordHash": hashed_password.decode()
        }), 201

    except Exception as e:
        logger.error("❌ Error general en register_user: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500


@ruta_user.route("/login", methods=["POST"])
def login_user():
    try:
        data = request.json
        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            return jsonify({"error": "Email y contraseña son requeridos"}), 400

        user = User.query.filter_by(email=email).first()
        if not user or not verify_password(password, user.password_hash):
            return jsonify({"error": "Credenciales inválidas"}), 401

        token = generate_uuid()
        user.token = token
        db.session.commit()

        return jsonify({
            "message": "Login exitoso",
            "token": token,
            "user": user_schema.dump(user)
        }), 200

    except Exception as e:
        logger.error("❌ Error en login_user: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_user.route("/logout", methods=["POST"])
def logout_user():
    try:
        token = request.headers.get("Authorization")
        if not token:
            return jsonify({"error": "Token no proporcionado"}), 401

        user = User.query.filter_by(token=token).first()
        if not user:
            return jsonify({"error": "Token inválido"}), 401

        user.token = None
        db.session.commit()
        return jsonify({"message": "Logout exitoso"}), 200

    except Exception as e:
        logger.error("❌ Error en logout_user: %s", str(e))
        logger.debug(traceback.format_exc())
        return jsonify({"error": "Error interno del servidor"}), 500

@ruta_user.route("/updateUser/<string:user_id>", methods=["PUT"])
def update_user(user_id):
    try:
        user = User.query.get(user_id)
        if not user:
            return jsonify({"error": "Usuario no encontrado"}), 404

        data = request.json
        if "email" in data:
            user.email = data["email"]
        if "name" in data:
            user.name = data["name"]
        if "password" in data:
            hashed_password, salt = hash_password(data["password"])
            user.password_hash = hashed_password
            user.salt = salt

        # Actualizar en MongoDB
        mongo = current_app.config['MONGO_DB']
        mongo.users.update_one(
            {"_id": user_id},
            {"$set": {
                "email": user.email,
                "name": user.name,
                "passwordHash": user.password_hash.decode(),
                "salt": user.salt.decode(),
                "updatedAt": datetime.utcnow().isoformat()
            }}
        )
        logger.info("✅ Usuario actualizado correctamente en MongoDB")

        db.session.commit()
        return jsonify({"message": "Usuario actualizado correctamente"}), 200

    except Exception as e:
        logger.error("❌ Error en update_user: %s", str(e))
        logger.debug(traceback.format_exc())
        db.session.rollback()
        return jsonify({"error": "Error interno del servidor"}), 500
