from flask import Flask, current_app
from flask_sqlalchemy import SQLAlchemy
from flask_marshmallow import Marshmallow
from pymongo import MongoClient, errors as mongo_errors
import pymysql
import os
import time

db = SQLAlchemy()
ma = Marshmallow()
mongo_client = None
mongo_db = None

def get_mongo_db():
    if not mongo_db:
        raise RuntimeError("MongoDB no ha sido inicializado. Asegúrate de llamar a init_app primero.")
    return mongo_db

def wait_for_mysql():
    host = os.getenv("DB_HOST", "localhost")
    port = int(os.getenv("DB_PORT", "3306"))
    user = os.getenv("DB_USER", "root")
    password = os.getenv("DB_PASSWORD", "root")
    database = os.getenv("DB_NAME", "notenest")

    print(f"⏳ Esperando que MySQL esté disponible en {host}:{port}...")

    while True:
        try:
            conn = pymysql.connect(host=host, port=port, user=user, password=password, database=database)
            conn.close()
            print("✅ MySQL está disponible.")
            break
        except Exception:
            print("❌ Base de datos MySQL no disponible aún, reintentando en 2 segundos...")
            time.sleep(2)

def wait_for_mongodb():
    host = os.getenv("MONGO_HOST", "localhost")
    port = int(os.getenv("MONGO_PORT", "27017"))
    print(f"⏳ Esperando que MongoDB esté disponible en {host}:{port}...")

    while True:
        try:
            client = MongoClient(host=host, port=port, serverSelectionTimeoutMS=2000)
            client.admin.command('ping')
            print("✅ MongoDB está disponible.")
            return client
        except mongo_errors.ServerSelectionTimeoutError:
            print("❌ MongoDB no disponible aún, reintentando en 2 segundos...")
            time.sleep(2)

def init_app(app: Flask):
    global mongo_client, mongo_db

    # 🔸 Esperar a MySQL y MongoDB
    wait_for_mysql()
    mongo_client = wait_for_mongodb()

    # 🔸 Configurar SQLAlchemy con MySQL
    db_user = os.environ.get("DB_USER", "root")
    db_pass = os.environ.get("DB_PASSWORD", "root")
    db_host = os.environ.get("DB_HOST", "localhost")
    db_port = os.environ.get("DB_PORT", "3306")
    db_name = os.environ.get("DB_NAME", "notenest")

    app.config['SQLALCHEMY_DATABASE_URI'] = (
        f"mysql+pymysql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
    )
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)
    ma.init_app(app)

    # 🔸 Inicializar base de datos MongoDB
    mongo_db_name = os.environ.get("MONGO_DB", "notenest_mongo")
    mongo_db = mongo_client[mongo_db_name]
    
    # Guardar mongo_db en la configuración de la aplicación
    app.config['MONGO_DB'] = mongo_db

    with app.app_context():
        # Asegurar que todas las colecciones necesarias existen
        collections = ['notes', 'users', 'sessions', 'comments', 'note_files']
        for collection in collections:
            if collection not in mongo_db.list_collection_names():
                mongo_db.create_collection(collection)

    print("✅ Conexión a MySQL y MongoDB establecida correctamente.")
