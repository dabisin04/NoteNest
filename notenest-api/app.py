# app.py

from flask import Flask
from app.config.db import init_app, db
from app.api.user import ruta_user
from app.api.note import ruta_note
from app.api.session import ruta_session
from app.api.comment import ruta_comment

def create_app():
    app = Flask(__name__)
    init_app(app)  # Inicializa MySQL y MongoDB

    # Registrar blueprints
    app.register_blueprint(ruta_user, url_prefix="/api")
    app.register_blueprint(ruta_note, url_prefix="/api")
    app.register_blueprint(ruta_session, url_prefix="/api")
    app.register_blueprint(ruta_comment, url_prefix="/api")

    with app.app_context():
        db.create_all()

    return app

# Solo si se ejecuta directamente
if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=5000, debug=True)
