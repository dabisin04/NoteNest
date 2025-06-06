import 'package:uuid/uuid.dart';

class Comment {
  final String id;
  final String noteId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final String rootComment;

  Comment({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    required this.rootComment,
  });

  factory Comment.create({
    required String noteId,
    required String userId,
    required String userName,
    required String content,
    String? parentId,
  }) {
    final now = DateTime.now();
    final id = const Uuid().v4();
    return Comment(
      id: id,
      noteId: noteId,
      userId: userId,
      userName: userName,
      content: content,
      createdAt: now,
      updatedAt: now,
      parentId: parentId,
      rootComment: parentId ?? id,
    );
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? const Uuid().v4(),
      noteId: map['noteId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anónimo',
      content: map['content'] ?? '',
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      parentId: map['parentId'],
      rootComment: map['rootComment'] ?? map['id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'parentId': parentId,
      'rootComment': rootComment,
    };
  }

  Comment copyWith({String? content}) {
    return Comment(
      id: id,
      noteId: noteId,
      userId: userId,
      userName: userName,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      parentId: parentId,
      rootComment: rootComment,
    );
  }
}
