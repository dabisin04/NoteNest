import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_marshmallow import Marshmallow

# Crear instancia de Flask
app = Flask(__name__)

# Variables de entorno desde Docker o valores por defecto
DB_HOST = os.getenv('DB_HOST', 'db')
DB_USER = os.getenv('DB_USER', 'notenest')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'notenest')
DB_NAME = os.getenv('DB_NAME', 'notenest')

# URI de conexión a MySQL
app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.secret_key = os.getenv('SECRET_KEY', 'dev')

# Inicializar extensiones
db = SQLAlchemy(app)
ma = Marshmallow(app) 