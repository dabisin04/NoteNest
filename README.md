# NoteNest 📝

NoteNest es una aplicación de notas colaborativa que permite a los usuarios crear, compartir y gestionar notas con soporte para archivos adjuntos.

## Estructura del Proyecto

```
notenest/
├── notenest-api/           # Backend (Flask)
│   ├── app/
│   │   ├── api/           # Endpoints de la API
│   │   ├── models/        # Modelos de datos
│   │   └── config/        # Configuración
│   └── docker-compose.yml # Configuración de Docker
│
└── notenest/              # Frontend (Flutter)
    ├── lib/
    │   ├── application/   # Lógica de negocio (BLoC)
    │   ├── domain/        # Entidades y repositorios
    │   ├── infrastructure/# Implementaciones
    │   └── presentation/  # UI
    └── pubspec.yaml       # Dependencias
```

## Características Principales

- 📝 Creación y edición de notas
- 📎 Soporte para archivos adjuntos
- 👥 Notas públicas y privadas
- 💬 Sistema de comentarios
- ❤️ Sistema de likes
- 🔍 Búsqueda de notas
- 📱 Sincronización offline

## API Endpoints

### Autenticación

#### Login
```http
POST /api/login
Content-Type: application/json

{
    "email": "usuario@ejemplo.com",
    "password": "contraseña123"
}
```

#### Registro
```http
POST /api/register
Content-Type: application/json

{
    "name": "Usuario Ejemplo",
    "email": "usuario@ejemplo.com",
    "password": "contraseña123"
}
```

### Notas

#### Obtener todas las notas
```http
GET /api/notes
```

#### Obtener notas públicas
```http
GET /api/publicNotes
```

#### Obtener notas por usuario
```http
GET /api/notesByUser/{userId}
```

#### Crear nota
```http
POST /api/addNote
Content-Type: application/json

{
    "title": "Mi Nota",
    "content": "Contenido de la nota",
    "isPublic": false,
    "userId": "user-id",
    "files": [
        {
            "fileUrl": "nombre_archivo.jpg"
        }
    ]
}
```

#### Actualizar nota
```http
PUT /api/updateNote/{noteId}
Content-Type: application/json

{
    "title": "Título Actualizado",
    "content": "Contenido actualizado",
    "isPublic": true
}
```

#### Eliminar nota
```http
DELETE /api/deleteNote/{noteId}
```

### Archivos

#### Obtener archivos de una nota
```http
GET /api/noteFiles/{noteId}
```

#### Agregar archivo a nota
```http
POST /api/addNoteFile
Content-Type: application/json

{
    "noteId": "note-id",
    "fileUrl": "nombre_archivo.jpg"
}
```

#### Eliminar archivo
```http
DELETE /api/deleteNoteFile/{fileId}
```

### Comentarios

#### Obtener comentarios de una nota
```http
GET /api/comments/{noteId}
```

#### Agregar comentario
```http
POST /api/addComment
Content-Type: application/json

{
    "noteId": "note-id",
    "userId": "user-id",
    "content": "Contenido del comentario",
    "parentId": null
}
```

#### Eliminar comentario
```http
DELETE /api/deleteComment/{commentId}
```

## Ejecutar el Proyecto

### Backend (API)

1. Navegar al directorio de la API:
```bash
cd notenest-api
```

2. Iniciar con Docker:
```bash
docker-compose up --build
```

La API estará disponible en `http://localhost:5000`

### Frontend (Flutter)

1. Navegar al directorio de la aplicación:
```bash
cd notenest
```

2. Instalar dependencias:
```bash
flutter pub get
```

3. Ejecutar la aplicación:
```bash
flutter run
```

## Tecnologías Utilizadas

- **Backend**:
  - Flask (Python)
  - SQLAlchemy
  - MySQL
  - Docker

- **Frontend**:
  - Flutter
  - BLoC Pattern
  - SQLite (almacenamiento local)
  - Provider

## Notas Adicionales

- La API utiliza autenticación basada en tokens
- Los archivos se almacenan localmente en el dispositivo
- La sincronización se realiza automáticamente cuando hay conexión
- Las notas privadas solo son visibles para su autor

## Contribuir

1. Fork el proyecto
2. Crea tu rama de características (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE.md](LICENSE.md) para más detalles. 
