// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:temp/core/constants/api_constants.dart';
import 'package:temp/core/services/sqlite_service.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:temp/domain/repositories/auth_repository.dart';
import 'package:temp/domain/repositories/note_repository.dart';

/// Implementación del repositorio de notas que maneja la persistencia y sincronización
/// de notas entre el almacenamiento local (SQLite) y el servidor remoto.
///
/// Esta clase implementa la interfaz NoteRepository y proporciona funcionalidad para:
/// - Crear, leer, actualizar y eliminar notas
/// - Gestionar archivos adjuntos a las notas
/// - Sincronizar datos entre el almacenamiento local y el servidor
/// - Manejar operaciones offline y online
class NoteRepositoryImpl implements NoteRepository {
  final AuthRepository authRepository;

  NoteRepositoryImpl({required this.authRepository});

  /// Obtiene la instancia de la base de datos SQLite
  Future<Database> get _db async => await SQLiteService.instance;

  /// Verifica si hay conexión a internet intentando resolver google.com
  /// Retorna true si hay conexión, false en caso contrario
  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Normaliza el endpoint de la API eliminando el slash inicial si existe
  String _sanitize(String endpoint) {
    return endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  }

  /// Intenta realizar una petición POST a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
  /// [data] - Datos a enviar en el cuerpo de la petición
  /// Retorna la respuesta HTTP si fue exitosa, null en caso contrario
  Future<http.Response?> _tryPostToApi(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${_sanitize(endpoint)}');
      print('🌐 POST a $uri con datos: $data');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data))
          .timeout(const Duration(seconds: 10));

      print('📡 Respuesta: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ POST exitoso a: $endpoint');
        return response;
      } else {
        print('❌ POST falló: ${response.body}');
      }
    } catch (e) {
      print('⏱️ Error en POST a $endpoint: $e');
    }
    return null;
  }

  /// Intenta realizar una petición GET a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
  /// Retorna la respuesta HTTP si fue exitosa, null en caso contrario
  Future<http.Response?> _tryGetFromApi(String endpoint) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${_sanitize(endpoint)}');
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        print('✅ Datos obtenidos de API: $endpoint');
        return response;
      } else {
        print('❌ Falló obtención de datos: ${response.body}');
      }
    } catch (e) {
      print('⏱️ Error al obtener datos de API: $e');
    }
    return null;
  }

  /// Intenta realizar una petición PUT a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
  /// [data] - Datos a enviar en el cuerpo de la petición
  /// Retorna la respuesta HTTP si fue exitosa, null en caso contrario
  Future<http.Response?> _tryPutToApi(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${_sanitize(endpoint)}');
      final response = await http
          .put(uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ PUT exitoso: $endpoint');
        return response;
      } else {
        print('❌ PUT fallo: ${response.body}');
      }
    } catch (e) {
      print('⏱️ PUT error en $endpoint: $e');
    }
    return null;
  }

  /// Intenta realizar una petición DELETE a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
  Future<void> _tryDeleteFromApi(String endpoint) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${_sanitize(endpoint)}');
      final response = await http.delete(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Eliminación exitosa en API: $endpoint');
      } else {
        print('❌ Falló eliminación: ${response.body}');
      }
    } catch (e) {
      print('⏱️ Error al eliminar en API: $e');
    }
  }

  /// Obtiene los archivos adjuntos de una nota específica
  ///
  /// [noteId] - ID de la nota cuyos archivos se quieren obtener
  /// Retorna una lista de mapas con la información de los archivos
  @override
  Future<List<Map<String, dynamic>>> getNoteFiles(String noteId) async {
    print('📎 [NoteRepository] Obteniendo archivos para nota: $noteId');
    final db = await _db;

    try {
      if (await _isOnline()) {
        final response = await _tryGetFromApi('noteFiles/$noteId');
        if (response != null) {
          if (response.statusCode == 404) {
            print('⚠️ [NoteRepository] Nota no encontrada en el servidor');
            return [];
          }

          final List<Map<String, dynamic>> remoteFiles =
              List<Map<String, dynamic>>.from(json.decode(response.body));
          print(
              '✅ [NoteRepository] Archivos obtenidos de API: ${remoteFiles.length}');

          // Guardar archivos en SQLite
          for (var file in remoteFiles) {
            try {
              await db.insert(
                'note_files',
                {
                  'id': file['id'],
                  'noteId': file['noteId'],
                  'fileUrl': file['fileUrl'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              print(
                  '💾 [NoteRepository] Archivo guardado en SQLite: ${file['fileUrl']}');
            } catch (e) {
              print(
                  '⚠️ [NoteRepository] Error guardando archivo en SQLite: $e');
            }
          }
          return remoteFiles;
        }
      }

      // Si está offline o falló la API, obtener archivos de SQLite
      final localFiles = await db.query(
        'note_files',
        where: 'noteId = ?',
        whereArgs: [noteId],
      );
      print(
          '📱 [NoteRepository] Archivos locales encontrados: ${localFiles.length}');
      return localFiles;
    } catch (e) {
      print('❌ [NoteRepository] Error obteniendo archivos: $e');
      return [];
    }
  }

  /// Elimina un archivo adjunto de una nota
  ///
  /// [fileId] - ID del archivo a eliminar
  @override
  Future<void> deleteNoteFile(String fileId) async {
    final db = await _db;

    await db.delete(
      'note_files',
      where: 'id = ?',
      whereArgs: [fileId],
    );

    if (await _isOnline()) {
      await _tryDeleteFromApi('deleteNoteFile/$fileId');
    }
  }

  /// Comprime un archivo si es una imagen
  ///
  /// [file] - Archivo a comprimir
  /// Retorna el archivo comprimido si es una imagen, el original si no lo es
  Future<File?> compressFile(File file) async {
    final ext = file.path.split('.').last.toLowerCase();

    // Solo imágenes soportadas
    if (["jpg", "jpeg", "png", "webp"].contains(ext)) {
      final dir = await getTemporaryDirectory();
      final nameWithoutExtension = file.path.split('/').last.split('.').first;

      final targetPath =
          '${dir.path}/compressed_${nameWithoutExtension}.jpg'; // <- termina en .jpg garantizado

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        format: CompressFormat.jpeg, // explícito
      );

      return result != null ? File(result.path) : null;
    }

    return file; // no se comprime si no es imagen
  }

  /// Sube una nueva nota con sus archivos adjuntos
  ///
  /// [note] - Nota a subir
  /// [files] - Lista de archivos adjuntos
  @override
  Future<void> uploadNote(Note note, List<File> files) async {
    final db = await _db;

    print('📝 [NoteRepository] Iniciando subida de nota: ${note.id}');
    final user = await authRepository.getUserById(note.userId);
    if (user == null) {
      print('❌ Usuario no encontrado');
      throw Exception('Usuario no encontrado');
    }

    await db.insert('notes', note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);

    final appDir = await getApplicationDocumentsDirectory();
    final List<Map<String, dynamic>> filesToUpload = [];

    for (final file in files) {
      final filename = file.path.split('/').last;
      final fileId = const Uuid().v4();
      final localPath = '${appDir.path}/$filename';
      print('📎 Archivo: $filename');

      final compressed = await compressFile(file);
      final storedFile =
          await compressed?.copy(localPath) ?? await file.copy(localPath);

      final noteFile = {
        'id': fileId,
        'noteId': note.id,
        'fileUrl': filename, // 
      };

      filesToUpload.add(noteFile);

      await db.insert('note_files', noteFile,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (await _isOnline()) {
      print('🌐 Subiendo nota a API');
      await _tryPostToApi('addNote', {
        ...note.toMap(),
        'files': filesToUpload,
      });
      print('✅ Nota sincronizada con servidor');
    } else {
      print('📱 Nota guardada localmente sin conexión');
    }
  }

  /// Alias para uploadNote que mantiene compatibilidad con la interfaz
  @override
  Future<void> uploadNoteWithFiles(Note note, List<File> files) async {
    await uploadNote(note, files);
  }

  /// Actualiza una nota existente
  ///
  /// [updatedNote] - Nota con los datos actualizados
  @override
  Future<void> updateNote(Note updatedNote) async {
    final db = await _db;

    await db.update(
      'notes',
      updatedNote.toMap(),
      where: 'id = ?',
      whereArgs: [updatedNote.id],
    );

    if (await _isOnline()) {
      await _tryPutToApi('updateNote/${updatedNote.id}', updatedNote.toMap());
    }
  }

  /// Actualiza una nota y agrega nuevos archivos adjuntos
  ///
  /// [updatedNote] - Nota con los datos actualizados
  /// [newFiles] - Lista de nuevos archivos a adjuntar
  @override
  Future<void> updateNoteWithFiles(
      Note updatedNote, List<File> newFiles) async {
    final db = await _db;

    // Primero actualizamos la nota
    await db.update(
      'notes',
      updatedNote.toMap(),
      where: 'id = ?',
      whereArgs: [updatedNote.id],
    );

    if (await _isOnline()) {
      // Actualizar la nota primero
      await _tryPutToApi('updateNote/${updatedNote.id}', updatedNote.toMap());
    }

    final appDir = await getApplicationDocumentsDirectory();
    final List<Map<String, dynamic>> uploadedFiles = [];

    // Procesar cada archivo nuevo
    for (final file in newFiles) {
      final filename = file.path.split('/').last;
      final fileId = const Uuid().v4();
      final localPath = '${appDir.path}/$filename';
      print('📎 Procesando archivo: $filename');

      try {
        final compressed = await compressFile(file);
        await compressed?.copy(localPath) ?? await file.copy(localPath);

        final noteFile = {
          'id': fileId,
          'noteId': updatedNote.id,
          'fileUrl': filename,
        };

        // Guardar en SQLite
        await db.insert(
          'note_files',
          noteFile,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        uploadedFiles.add(noteFile);

        // Si estamos online, subir cada archivo individualmente
        if (await _isOnline()) {
          final response = await _tryPostToApi('addNoteFile', noteFile);
          if (response == null) {
            print('❌ Error al subir archivo: $filename');
          }
        }
      } catch (e) {
        print('❌ Error procesando archivo $filename: $e');
      }
    }

    print('✅ Archivos procesados: ${uploadedFiles.length}');
  }

  /// Descarga una nota específica del servidor
  ///
  /// [noteId] - ID de la nota a descargar
  @override
  Future<void> downloadNote(String noteId) async {
    final db = await _db;

    // Verificar si la nota ya está en SQLite
    final localNotes = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (localNotes.isNotEmpty) {
      return; // Nota ya descargada
    }

    // Intentar descargar desde API si hay conexión
    if (await _isOnline()) {
      final response = await _tryGetFromApi('notes/$noteId');
      if (response != null) {
        final note = Note.fromMap(json.decode(response.body));
        await db.insert(
          'notes',
          note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        throw Exception('Failed to download note');
      }
    } else {
      throw Exception('No connection to download note');
    }
  }

  /// Elimina una nota y sus archivos adjuntos
  ///
  /// [noteId] - ID de la nota a eliminar
  @override
  Future<void> deleteNote(String noteId) async {
    final db = await _db;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (await _isOnline()) {
      await _tryDeleteFromApi('notes/$noteId');
    }
  }

  /// Obtiene una lista de notas según los criterios especificados
  ///
  /// [onlyPublic] - Si es true, solo retorna notas públicas
  /// [userId] - Si se especifica, solo retorna notas de ese usuario
  /// Retorna una lista de notas que cumplen con los criterios
  @override
  Future<List<Note>> getNotes({bool onlyPublic = false, String? userId}) async {
    print(
        '📝 [NoteRepository] Obteniendo notas (onlyPublic: $onlyPublic, userId: $userId)');
    final db = await _db;
    String? where;
    List<dynamic> whereArgs = [];

    if (onlyPublic && userId != null) {
      where = 'isPublic = ? AND userId = ?';
      whereArgs = [1, userId];
    } else if (onlyPublic) {
      where = 'isPublic = ?';
      whereArgs = [1];
    } else if (userId != null) {
      where = 'userId = ?';
      whereArgs = [userId];
    }

    print('🔍 [NoteRepository] Consulta SQLite: where=$where, args=$whereArgs');
    final maps = await db.query(
      'notes',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    final localNotes = maps.map((map) => Note.fromMap(map)).toList();
    print(
        '📱 [NoteRepository] Notas locales encontradas: ${localNotes.length}');

    // Intentar obtener desde API si hay conexión
    if (await _isOnline()) {
      String endpoint;
      if (onlyPublic) {
        endpoint = 'publicNotes';
      } else if (userId != null) {
        endpoint = 'notesByUser/$userId';
      } else {
        endpoint = 'notes';
      }

      print('🌐 [NoteRepository] Consultando API: $endpoint');
      final response = await _tryGetFromApi(endpoint);
      if (response != null) {
        final remoteNotes = (json.decode(response.body) as List)
            .map((map) => Note.fromMap(map))
            .toList();
        print(
            '✅ [NoteRepository] Notas obtenidas de API: ${remoteNotes.length}');

        // Guardar en SQLite
        for (var note in remoteNotes) {
          await db.insert(
            'notes',
            note.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        print('💾 [NoteRepository] Notas guardadas en SQLite');
        return remoteNotes;
      }
    }

    return localNotes;
  }

  /// Busca notas que coincidan con el texto de búsqueda
  ///
  /// [query] - Texto a buscar en título y contenido
  /// Retorna una lista de notas que coinciden con la búsqueda
  @override
  Future<List<Note>> searchNotes(String query) async {
    final db = await _db;
    final maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );

    final localNotes = maps.map((map) => Note.fromMap(map)).toList();

    // Intentar buscar en API si hay conexión
    if (await _isOnline()) {
      final response = await _tryGetFromApi('notes/search?query=$query');
      if (response != null) {
        final remoteNotes = (json.decode(response.body) as List)
            .map((map) => Note.fromMap(map))
            .toList();
        // Guardar en SQLite
        for (var note in remoteNotes) {
          await db.insert(
            'notes',
            note.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return remoteNotes;
      }
    }

    return localNotes;
  }

  /// Guarda una nota en el caché local
  ///
  /// [note] - Nota a guardar en caché
  @override
  Future<void> cacheNote(Note note) async {
    final db = await _db;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Sincroniza las notas locales con el servidor
  /// Solo se ejecuta si hay conexión a internet
  @override
  Future<void> syncNotes() async {
    if (!await _isOnline()) {
      print('⏱️ Sin conexión, sincronización pospuesta');
      return;
    }

    final db = await _db;
    final notes = await db.query('notes');

    for (var noteMap in notes) {
      final note = Note.fromMap(noteMap);
      await _tryPostToApi('notes', note.toMap());
    }

    // Limpiar la base de datos local después de sincronizar
    await db.delete('notes');
    print('🧹 Base de datos local (notes) limpiada tras sincronización');
  }

  /// Obtiene el autor de una nota específica
  ///
  /// [noteId] - ID de la nota
  /// Retorna el usuario autor de la nota
  @override
  Future<User> getNoteAuthor(String noteId) async {
    final db = await _db;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (maps.isEmpty) {
      throw Exception('Note not found');
    }

    final note = Note.fromMap(maps.first);
    final user = await authRepository.getUserById(note.userId);
    if (user == null) {
      throw Exception('Author not found');
    }

    return user;
  }

  /// Verifica si un usuario es el autor de una nota
  ///
  /// [noteId] - ID de la nota
  /// [userId] - ID del usuario a verificar
  /// Retorna true si el usuario es el autor, false en caso contrario
  @override
  Future<bool> verifyNoteAuthor(String noteId, String userId) async {
    final db = await _db;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (maps.isEmpty) {
      return false;
    }

    final note = Note.fromMap(maps.first);
    return note.userId == userId;
  }
}
