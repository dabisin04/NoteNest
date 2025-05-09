import sys
import os

# Añadir el directorio raíz al path de Python
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask
from app.config.db import app, db

# Importar Blueprints
from app.api.user import ruta_user
from app.api.note import ruta_note
from app.api.comment import ruta_comment
from app.api.session import ruta_session

# Registrar Blueprints con prefijo /api
app.register_blueprint(ruta_user, url_prefix="/api")
app.register_blueprint(ruta_note, url_prefix="/api")
app.register_blueprint(ruta_comment, url_prefix="/api")
app.register_blueprint(ruta_session, url_prefix="/api")

# Ruta principal
@app.route("/")
def index():
    return "✅ API de NoteNest funcionando correctamente"

# Iniciar servidor y crear las tablas si no existen
if __name__ == "__main__":
    with app.app_context():
        db.create_all()  # Crea todas las tablas definidas en modelos
    app.run(debug=True, port=5000, host="0.0.0.0")
