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

class NoteRepositoryImpl implements NoteRepository {
  final AuthRepository authRepository;

  NoteRepositoryImpl({required this.authRepository});

  Future<Database> get _db async => await SQLiteService.instance;

  /// Verifica si hay conexión a internet.
  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _sanitize(String endpoint) {
    return endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
  }

  /// Intenta enviar una solicitud POST a la API.
  Future<http.Response?> _tryPostToApi(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${_sanitize(endpoint)}');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(data))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Nota sincronizada con API: $endpoint');
        return response;
      } else {
        print('❌ Falló sincronización: ${response.body}');
      }
    } catch (e) {
      print('⏱️ Error al sincronizar con API: $e');
    }
    return null;
  }

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

  @override
  Future<List<Map<String, dynamic>>> getNoteFiles(String noteId) async {
    print('📎 [NoteRepository] Obteniendo archivos para nota: $noteId');
    final db = await _db;

    if (await _isOnline()) {
      final response = await _tryGetFromApi('noteFiles/$noteId');
      if (response != null) {
        final List<Map<String, dynamic>> remoteFiles =
            List<Map<String, dynamic>>.from(json.decode(response.body));
        print(
            '✅ [NoteRepository] Archivos obtenidos de API: ${remoteFiles.length}');

        // Guardar archivos en SQLite
        for (var file in remoteFiles) {
          await db.insert(
            'note_files',
            file,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print(
              '💾 [NoteRepository] Archivo guardado en SQLite: ${file['fileUrl']}');
        }
        return remoteFiles;
      }
    }

    // Si está offline, obtener archivos de SQLite
    final localFiles = await db.query(
      'note_files',
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
    print(
        '📱 [NoteRepository] Archivos locales encontrados: ${localFiles.length}');
    return localFiles;
  }

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
      final localPath = '${appDir.path}/$filename';
      print('📎 Archivo: $filename');

      final compressed = await compressFile(file);
      final storedFile =
          await compressed?.copy(localPath) ?? await file.copy(localPath);

      final noteFile = {
        'id': const Uuid().v4(),
        'noteId': note.id,
        'fileUrl': filename,
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

  @override
  Future<void> uploadNoteWithFiles(Note note, List<File> files) async {
    await uploadNote(note, files);
  }

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

  @override
  Future<void> updateNoteWithFiles(
      Note updatedNote, List<File> newFiles) async {
    final db = await _db;

    await db.update(
      'notes',
      updatedNote.toMap(),
      where: 'id = ?',
      whereArgs: [updatedNote.id],
    );

    final appDir = await getApplicationDocumentsDirectory();

    for (final file in newFiles) {
      final ext = file.path.split('.').last.toLowerCase();
      final filename = file.path.split('/').last;
      final localPath = '${appDir.path}/$filename';

      final compressed = await compressFile(file);
      final storedFile =
          await compressed?.copy(localPath) ?? await file.copy(localPath);

      final noteFile = {
        'id': const Uuid().v4(),
        'noteId': updatedNote.id,
        'fileUrl': storedFile.path,
      };

      await db.insert(
        'note_files',
        noteFile,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (await _isOnline()) {
      await _tryPutToApi('updateNote/${updatedNote.id}', updatedNote.toMap());
      for (final file in newFiles) {
        await _tryPostToApi('addNoteFile', {
          'noteId': updatedNote.id,
          'fileUrl': file.path.split('/').last,
        });
      }
    }
  }

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

  @override
  Future<void> cacheNote(Note note) async {
    final db = await _db;
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
