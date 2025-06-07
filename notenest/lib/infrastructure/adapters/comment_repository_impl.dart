import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:temp/core/constants/api_constants.dart';
import 'package:temp/core/services/sqlite_service.dart';
import 'package:temp/domain/entities/comment.dart';
import 'package:temp/domain/repositories/auth_repository.dart';
import 'package:temp/domain/repositories/comment_repository.dart';

/// Implementación del repositorio de comentarios que maneja la persistencia y sincronización
/// de comentarios entre el almacenamiento local (SQLite) y el servidor remoto.
///
/// Esta clase implementa la interfaz CommentRepository y proporciona funcionalidad para:
/// - Crear, leer, actualizar y eliminar comentarios
/// - Gestionar respuestas a comentarios (threads)
/// - Sincronizar datos entre el almacenamiento local y el servidor
/// - Manejar operaciones offline y online
class CommentRepositoryImpl implements CommentRepository {
  final AuthRepository authRepository;

  CommentRepositoryImpl({required this.authRepository});

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
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ POST: $endpoint');
        return response;
      } else {
        print('❌ POST fallo: ${response.body}');
      }
    } catch (e) {
      print('⏱️ POST error: $e');
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
        print('✅ GET: $endpoint');
        return response;
      } else {
        print('❌ GET fallo: ${response.body}');
      }
    } catch (e) {
      print('⏱️ GET error: $e');
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
        print('✅ DELETE: $endpoint');
      } else {
        print('❌ DELETE fallo: ${response.body}');
      }
    } catch (e) {
      print('⏱️ DELETE error: $e');
    }
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
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        print('✅ PUT: $endpoint');
        return response;
      } else {
        print('❌ PUT fallo: ${response.body}');
      }
    } catch (e) {
      print('⏱️ PUT error: $e');
    }
    return null;
  }

  /// Agrega un nuevo comentario a una nota
  ///
  /// [comment] - Comentario a agregar
  @override
  Future<void> commentNote(Comment comment) async {
    final db = await _db;

    // Se inserta el comentario en la base de datos local
    await db.insert(
      'comments',
      comment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Si hay conexión a internet, se agrega el comentario en el servidor
    if (await _isOnline()) {
      await _tryPostToApi('addComment', comment.toMap());
    }
  }

  /// Agrega una respuesta a un comentario existente
  ///
  /// [reply] - Comentario de respuesta
  /// Maneja la lógica de threads de comentarios
  @override
  Future<void> replyComment(Comment reply) async {
    final db = await _db;

    // Si el comentario tiene un padre, se obtiene el comentario padre
    if (reply.parentId != null) {
      final parentComments = await db.query(
        'comments',
        where: 'id = ?',
        whereArgs: [reply.parentId],
      );

      // Si el comentario padre no existe, se lanza una excepción
      if (parentComments.isEmpty) {
        throw Exception('Parent comment not found');
      }

      // Se obtiene el comentario padre
      final parentComment = Comment.fromMap(parentComments.first);
      final rootId = parentComment.parentId != null
          ? parentComment.rootComment
          : parentComment.id;

      reply = reply.copyWithRoot(rootId);
    }

    // Se inserta el comentario en la base de datos local
    await db.insert(
      'comments',
      reply.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Si hay conexión a internet, se agrega el comentario en el servidor
    if (await _isOnline()) {
      await _tryPostToApi('replyComment', reply.toMap());
    }
  }

  /// Edita el contenido de un comentario existente
  ///
  /// [commentId] - ID del comentario a editar
  /// [newContent] - Nuevo contenido del comentario
  /// Verifica que el usuario actual sea el autor del comentario
  @override
  Future<void> editComment(String commentId, String newContent) async {
    final db = await _db;

    // Se obtiene el comentario de la base de datos local
    final comments =
        await db.query('comments', where: 'id = ?', whereArgs: [commentId]);
    
    // Si el comentario no existe, se lanza una excepción
    if (comments.isEmpty) throw Exception('Comment not found');

    // Se obtiene el comentario
    final comment = Comment.fromMap(comments.first);

    // Se obtiene el usuario actual
    final currentUser = await authRepository.getCurrentUser();

    // Si el usuario actual no es el autor del comentario, se lanza una excepción
    if (currentUser == null || currentUser.id != comment.userId) {
      throw Exception('Unauthorized to edit comment');
    }

    // Si el nuevo contenido es vacío o tiene más de 500 caracteres, se lanza una excepción
    if (newContent.isEmpty || newContent.length > 500) {
      throw FormatException('Comment must be between 1 and 500 characters');
    }

    // Se actualiza el contenido del comentario en la base de datos local
    await db.update('comments', {'content': newContent},
        where: 'id = ?', whereArgs: [commentId]);

    // Si hay conexión a internet, se actualiza el contenido del comentario en el servidor
    if (await _isOnline()) {
      await _tryPutToApi('updateComment/$commentId', {'content': newContent});
    }
  }

  /// Elimina un comentario existente
  ///
  /// [commentId] - ID del comentario a eliminar
  /// Verifica que el usuario actual sea el autor del comentario
  @override
  Future<void> deleteComment(String commentId) async {
    final db = await _db;

    // Se obtiene el comentario de la base de datos local
    final comments =
        await db.query('comments', where: 'id = ?', whereArgs: [commentId]);
    
    // Si el comentario no existe, se lanza una excepción
    if (comments.isEmpty) throw Exception('Comment not found');

    // Se obtiene el comentario
    final comment = Comment.fromMap(comments.first);

    // Se obtiene el usuario actual
    final currentUser = await authRepository.getCurrentUser();

    // Si el usuario actual no es el autor del comentario, se lanza una excepción
    if (currentUser == null || currentUser.id != comment.userId) {
      throw Exception('Unauthorized to delete comment');
    }

    // Se elimina el comentario de la base de datos local
    await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);

    // Si hay conexión a internet, se elimina el comentario en el servidor
    if (await _isOnline()) {
      await _tryDeleteFromApi('deleteComment/$commentId');
    }
  }

  /// Incrementa el contador de likes de una nota
  ///
  /// [noteId] - ID de la nota a la que se dará like
  @override
  Future<void> likeNote(String noteId) async {
    final db = await _db;

    // Se incrementa el contador de likes de la nota en la base de datos local
    await db
        .rawUpdate('UPDATE notes SET likes = likes + 1 WHERE id = ?', [noteId]);

    // Si hay conexión a internet, se incrementa el contador de likes de la nota en el servidor
    if (await _isOnline()) {
      await _tryPutToApi('likeNote/$noteId', {});
    }
  }

  /// Decrementa el contador de likes de una nota
  ///
  /// [noteId] - ID de la nota a la que se quitará el like
  @override
  Future<void> unlikeNote(String noteId) async {
    final db = await _db;

    // Se decrementa el contador de likes de la nota en la base de datos local
    await db.rawUpdate(
        'UPDATE notes SET likes = MAX(likes - 1, 0) WHERE id = ?', [noteId]);

    // Si hay conexión a internet, se decrementa el contador de likes de la nota en el servidor
    if (await _isOnline()) {
      await _tryPutToApi('unlikeNote/$noteId', {});
    }
  }

  /// Obtiene todos los comentarios de una nota específica
  ///
  /// [noteId] - ID de la nota cuyos comentarios se quieren obtener
  /// Retorna una lista de comentarios ordenados por thread y fecha
  @override
  Future<List<Comment>> getComments(String noteId) async {
    final db = await _db;

    // Se obtienen los comentarios de la base de datos local
    final maps = await db.query(
      'comments',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'rootComment, createdAt',
    );

    // Se obtienen los comentarios de la base de datos local
    final localComments = maps.map((map) => Comment.fromMap(map)).toList();

    // Si hay conexión a internet, se obtienen los comentarios del servidor
    if (await _isOnline()) {
      final response = await _tryGetFromApi('commentsByNote/$noteId');
      if (response != null) {
        // Se obtienen los comentarios del servidor
        final remoteComments = (json.decode(response.body) as List)
            .map((map) => Comment.fromMap(map))
            .toList();

        // Se insertan los comentarios en la base de datos local
        for (var comment in remoteComments) {
          await db.insert(
            'comments',
            comment.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Se retornan los comentarios del servidor
        return remoteComments;
      }
    }

    // Se retornan los comentarios de la base de datos local
    return localComments;
  }

  /// Obtiene todas las respuestas a un comentario específico
  ///
  /// [commentId] - ID del comentario cuyas respuestas se quieren obtener
  /// Retorna una lista de comentarios ordenados por fecha
  @override
  Future<List<Comment>> getReplies(String commentId) async {
    final db = await _db;

    // Se obtienen las respuestas de la base de datos local
    final maps = await db.query(
      'comments',
      where: 'parentId = ?',
      whereArgs: [commentId],
      orderBy: 'createdAt',
    );

    // Se obtienen las respuestas de la base de datos local
    final localReplies = maps.map((map) => Comment.fromMap(map)).toList();

    // Si hay conexión a internet, se obtienen las respuestas del servidor
    if (await _isOnline()) {
      final response = await _tryGetFromApi('commentReplies/$commentId');
      if (response != null) {
        // Se obtienen las respuestas del servidor
        final remoteReplies = (json.decode(response.body) as List)
            .map((map) => Comment.fromMap(map))
            .toList();

        // Se insertan las respuestas en la base de datos local
        for (var reply in remoteReplies) {
          await db.insert(
            'comments',
            reply.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Se retornan las respuestas del servidor
        return remoteReplies;
      }
    }

    // Se retornan las respuestas de la base de datos local
    return localReplies;
  }

  /// Sincroniza los comentarios locales con el servidor
  /// Solo se ejecuta si hay conexión a internet
  @override
  Future<void> syncComments() async {
    if (!await _isOnline()) {
      print('⏱️ Sin conexión, sincronización pospuesta');
      return;
    }

    final db = await _db;
    final comments = await db.query('comments');

    for (var commentMap in comments) {
      final comment = Comment.fromMap(commentMap);
      await _tryPostToApi('addComment', comment.toMap());
    }

    await db.delete('comments');
    print('🧹 Comments locales sincronizados y limpiados');
  }
}

/// Extensión para agregar funcionalidad adicional a la clase Comment
extension on Comment {
  /// Crea una copia del comentario con un nuevo ID de comentario raíz
  ///
  /// [root] - ID del comentario raíz
  /// Retorna una nueva instancia de Comment con el rootComment actualizado
  Comment copyWithRoot(String root) {
    return Comment(
      id: id,
      noteId: noteId,
      userId: userId,
      userName: userName,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      parentId: parentId,
      rootComment: root,
    );
  }
}
