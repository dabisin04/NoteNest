# NoteNest 📝

NoteNest es una aplicación de notas con sincronización offline que permite a los usuarios crear, compartir y gestionar notas con archivos adjuntos. La aplicación utiliza una arquitectura híbrida con almacenamiento local y sincronización en la nube, permitiendo su uso sin conexión. 

## Arquitectura

### Backend (Flask + MySQL + MongoDB)
El backend utiliza una arquitectura híbrida con dos bases de datos:
- **MySQL**: Almacenamiento principal para datos estructurados (notas, usuarios, comentarios)
- **MongoDB**: Caché y sincronización rápida de datos, especialmente para archivos y estados

La sincronización entre bases de datos se maneja automáticamente en cada operación.

### Frontend (Flutter)
Utiliza Clean Architecture con tres capas principales:
- **Presentation**: UI y widgets (Material Design)
- **Domain**: Lógica de negocio y entidades
- **Infrastructure**: Implementaciones y adaptadores

## Bases de Datos

### MySQL (Principal)
Tablas principales:
- `users`: Información de usuarios
- `notes`: Notas y su contenido
- `comments`: Sistema de comentarios
- `note_files`: Metadatos de archivos
- `sessions`: Gestión de sesiones

### MongoDB (Sincronización)
Colecciones:
- `notes`: Caché de notas
- `users`: Datos de usuario
- `comments`: Comentarios
- `note_files`: Referencias a archivos
- `sessions`: Sesiones activas

### SQLite (Local en Flutter)
Almacenamiento local para:
- Notas offline
- Caché de archivos
- Datos de usuario
- Estado de sincronización

## API Endpoints

### Autenticación
```http
POST /api/login
POST /api/register
POST /api/createSession
DELETE /api/deleteSession/{userId}
POST /api/validateSession
```

### Notas
```http
GET /api/notes                    # Todas las notas
GET /api/publicNotes             # Notas públicas
GET /api/notesByUser/{userId}    # Notas por usuario
POST /api/addNote                # Nueva nota
PUT /api/updateNote/{noteId}     # Actualizar nota
DELETE /api/deleteNote/{noteId}  # Eliminar nota
PUT /api/likeNote/{noteId}       # Dar like
PUT /api/unlikeNote/{noteId}     # Quitar like
POST /api/sync                   # Sincronización
```

### Archivos
```http
GET /api/noteFiles/{noteId}          # Obtener archivos
POST /api/addNoteFile               # Agregar archivo
DELETE /api/deleteNoteFile/{fileId}  # Eliminar archivo
```

### Comentarios
```http
GET /api/commentsByNote/{noteId}    # Comentarios de nota
POST /api/addComment               # Nuevo comentario
POST /api/replyComment            # Responder comentario
PUT /api/updateComment/{commentId} # Actualizar comentario
DELETE /api/deleteComment/{commentId} # Eliminar comentario
```

## Gestión de Archivos

### Almacenamiento
- Los archivos se almacenan localmente en el directorio de la aplicación
- Se comprimen automáticamente las imágenes antes de guardar
- Soporte para múltiples tipos de archivo
- Vista previa para imágenes y documentos comunes

### Sincronización
- Los archivos se sincronizan bajo demanda
- Se mantiene un registro de archivos pendientes de sincronización
- Verificación de integridad mediante hashes

## Dependencias Principales

### Backend (requirements.txt)
```
flask
flask-sqlalchemy
flask-marshmallow
pymysql
pymongo
python-dotenv
```

### Frontend (pubspec.yaml)
```yaml
dependencies:
  flutter_bloc: ^8.0.0
  sqflite: ^2.0.0
  path_provider: ^2.0.0
  http: ^0.13.0
  image_picker: ^0.8.0
  file_picker: ^5.0.0
  shared_preferences: ^2.0.0
  flutter_image_compress: ^1.0.0
  open_file: ^3.0.0
  mime: ^1.0.0
```

## Características de Sincronización

- **Offline First**: Funciona sin conexión
- **Sincronización Bidireccional**: Cliente ↔ Servidor
- **Resolución de Conflictos**: Basada en timestamps
- **Cola de Sincronización**: Para operaciones pendientes
- **Estado de Conexión**: Monitoreo automático

## Seguridad

- Autenticación basada en tokens
- Almacenamiento seguro de credenciales
- Encriptación de datos sensibles
- Validación de sesiones

## Configuración del Proyecto

### Backend
1. Configurar variables de entorno:
```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root
DB_NAME=notenest
MONGO_HOST=localhost
MONGO_PORT=27017
MONGO_DB=notenest_mongo
```

2. Iniciar servicios:
```bash
docker-compose up --build
```

### Frontend
1. Configurar endpoint de API en `lib/core/constants/api_constants.dart`
2. Instalar dependencias:
```bash
flutter pub get
```

3. Ejecutar:
```bash
flutter run
```

## Desarrollo

### Estructura de Directorios
```
notenest/
├── lib/
│   ├── application/
│   │   ├── bloc/         # Estado y lógica
│   │   └── services/     # Servicios
│   ├── core/
│   │   ├── constants/    # Configuración
│   │   └── utils/        # Utilidades
│   ├── domain/
│   │   ├── entities/     # Modelos
│   │   └── repositories/ # Interfaces
│   ├── infrastructure/
│   │   ├── adapters/     # Implementaciones
│   │   └── datasources/  # Fuentes de datos
│   └── presentation/
│       ├── screens/      # Pantallas
│       └── widgets/      # Componentes
```

## Contribuir

1. Fork el proyecto
2. Crear rama de feature (`git checkout -b feature/NuevaCaracteristica`)
3. Commit cambios (`git commit -m 'Añadir nueva característica'`)
4. Push a la rama (`git push origin feature/NuevaCaracteristica`)
5. Crear Pull Request

## Licencia

Distribuido bajo la Licencia MIT. Ver `LICENSE` para más información. 
