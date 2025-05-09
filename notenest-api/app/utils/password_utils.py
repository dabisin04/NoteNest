import bcrypt
import uuid

def generate_salt():
    """Genera un salt aleatorio para la contraseña."""
    return bcrypt.gensalt()

def hash_password(password: str, salt: bytes = None) -> tuple:
    """Hashea una contraseña con un salt."""
    if salt is None:
        salt = generate_salt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed, salt

def verify_password(password: str, hashed_password: bytes) -> bool:
    """Verifica si una contraseña coincide con su hash."""
    return bcrypt.checkpw(password.encode('utf-8'), hashed_password)

def generate_uuid() -> str:
    """Genera un UUID único."""
    return str(uuid.uuid4()) 