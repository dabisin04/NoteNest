import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String title;
  final String? content; // Opcional para notas PDF
  final bool isPublic;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likes;

  Note({
    required this.id,
    required this.title,
    this.content,
    required this.isPublic,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.likes,
  }) {
    _validateTitle(title);
    _validateContent(content);
  }

  // Constructor factory para crear notas con ID automática
  factory Note.create({
    required String title,
    String? content,
    required bool isPublic,
    required String userId,
    int likes = 0,
  }) {
    final now = DateTime.now();
    return Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      isPublic: isPublic,
      userId: userId,
      createdAt: now,
      updatedAt: now,
      likes: likes,
    );
  }

  // Validación del título (mínimo 3 caracteres, máximo 100)
  void _validateTitle(String title) {
    if (title.length < 3 || title.length > 100) {
      throw FormatException('Title must be between 3 and 100 characters');
    }
  }

  // Validación del contenido (si existe, máximo 10000 caracteres)
  void _validateContent(String? content) {
    if (content != null && content.length > 10000) {
      throw FormatException('Content must not exceed 10000 characters');
    }
  }

  // Validar permisos de acceso (ejemplo básico)
  bool canAccess(String accessingUserId) {
    return isPublic || userId == accessingUserId;
  }

  // Crear Note desde un Map
  factory Note.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final title = map['title'];
    final userId = map['userId'] ?? map['user_id'];

    if (id == null || title == null || userId == null) {
      throw Exception("Campos obligatorios faltantes en el mapa de la nota");
    }

    return Note(
      id: id as String,
      title: title as String,
      content: map['content'] as String?,
      isPublic: map['isPublic'] == true ||
          map['isPublic'] == 1 ||
          map['is_public'] == true,
      userId: userId,
      createdAt:
          DateTime.tryParse(map['createdAt'] ?? map['created_at'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] ?? map['updated_at'] ?? '') ??
              DateTime.now(),
      likes: map['likes'] is int
          ? map['likes'] as int
          : int.tryParse('${map['likes']}') ?? 0,
    );
  }

  // Convertir Note a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'isPublic': isPublic ? 1 : 0, // Para SQLite
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'likes': likes,
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    bool? isPublic,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likes,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isPublic: isPublic ?? this.isPublic,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likes: likes ?? this.likes,
    );
  }
}
