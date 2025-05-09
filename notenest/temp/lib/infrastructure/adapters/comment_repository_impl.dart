import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:temp/core/constants/api_constants.dart';
import 'package:temp/core/services/sqlite_service.dart';
import 'package:temp/domain/entities/comment.dart';
import 'package:temp/domain/repositories/auth_repository.dart';
import 'package:temp/domain/repositories/comment_repository.dart';

class CommentRepositoryImpl implements CommentRepository {
  final AuthRepository authRepository;

  CommentRepositoryImpl({required this.authRepository});

  Future<Database> get _db async => await SQLiteService.instance;

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

  @override
  Future<void> commentNote(Comment comment) async {
    final db = await _db;
    await db.insert(
      'comments',
      comment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _isOnline()) {
      await _tryPostToApi('addComment', comment.toMap());
    }
  }

  @override
  Future<void> replyComment(Comment reply) async {
    final db = await _db;

    if (reply.parentId != null) {
      final parentComments = await db.query(
        'comments',
        where: 'id = ?',
        whereArgs: [reply.parentId],
      );
      if (parentComments.isEmpty) {
        throw Exception('Parent comment not found');
      }
      final parentComment = Comment.fromMap(parentComments.first);
      final rootId = parentComment.parentId != null
          ? parentComment.rootComment
          : parentComment.id;

      reply = reply.copyWithRoot(rootId);
    }

    await db.insert(
      'comments',
      reply.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _isOnline()) {
      await _tryPostToApi('replyComment', reply.toMap());
    }
  }

  @override
  Future<void> editComment(String commentId, String newContent) async {
    final db = await _db;
    final comments =
        await db.query('comments', where: 'id = ?', whereArgs: [commentId]);

    if (comments.isEmpty) throw Exception('Comment not found');

    final comment = Comment.fromMap(comments.first);
    final currentUser = await authRepository.getCurrentUser();

    if (currentUser == null || currentUser.id != comment.userId) {
      throw Exception('Unauthorized to edit comment');
    }

    if (newContent.isEmpty || newContent.length > 500) {
      throw FormatException('Comment must be between 1 and 500 characters');
    }

    await db.update('comments', {'content': newContent},
        where: 'id = ?', whereArgs: [commentId]);

    if (await _isOnline()) {
      await _tryPutToApi('updateComment/$commentId', {'content': newContent});
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final db = await _db;
    final comments =
        await db.query('comments', where: 'id = ?', whereArgs: [commentId]);

    if (comments.isEmpty) throw Exception('Comment not found');

    final comment = Comment.fromMap(comments.first);
    final currentUser = await authRepository.getCurrentUser();

    if (currentUser == null || currentUser.id != comment.userId) {
      throw Exception('Unauthorized to delete comment');
    }

    await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);

    if (await _isOnline()) {
      await _tryDeleteFromApi('deleteComment/$commentId');
    }
  }

  @override
  Future<void> likeNote(String noteId) async {
    final db = await _db;
    await db
        .rawUpdate('UPDATE notes SET likes = likes + 1 WHERE id = ?', [noteId]);

    if (await _isOnline()) {
      await _tryPutToApi('likeNote/$noteId', {});
    }
  }

  @override
  Future<void> unlikeNote(String noteId) async {
    final db = await _db;

    await db.rawUpdate(
        'UPDATE notes SET likes = MAX(likes - 1, 0) WHERE id = ?', [noteId]);

    if (await _isOnline()) {
      await _tryPutToApi('unlikeNote/$noteId', {});
    }
  }

  @override
  Future<List<Comment>> getComments(String noteId) async {
    final db = await _db;
    final maps = await db.query(
      'comments',
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'rootComment, createdAt',
    );

    final localComments = maps.map((map) => Comment.fromMap(map)).toList();

    if (await _isOnline()) {
      final response = await _tryGetFromApi('commentsByNote/$noteId');
      if (response != null) {
        final remoteComments = (json.decode(response.body) as List)
            .map((map) => Comment.fromMap(map))
            .toList();
        for (var comment in remoteComments) {
          await db.insert(
            'comments',
            comment.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return remoteComments;
      }
    }

    return localComments;
  }

  @override
  Future<List<Comment>> getReplies(String commentId) async {
    final db = await _db;
    final maps = await db.query(
      'comments',
      where: 'parentId = ?',
      whereArgs: [commentId],
      orderBy: 'createdAt',
    );

    final localReplies = maps.map((map) => Comment.fromMap(map)).toList();

    if (await _isOnline()) {
      final response = await _tryGetFromApi('commentReplies/$commentId');
      if (response != null) {
        final remoteReplies = (json.decode(response.body) as List)
            .map((map) => Comment.fromMap(map))
            .toList();
        for (var reply in remoteReplies) {
          await db.insert(
            'comments',
            reply.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        return remoteReplies;
      }
    }

    return localReplies;
  }

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

extension on Comment {
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
