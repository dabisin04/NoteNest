import 'package:uuid/uuid.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String? passwordHash;
  final String? salt;
  final String? token;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.passwordHash,
    this.salt,
    this.token,
    this.createdAt,
    this.updatedAt,
  }) {
    _validateEmail(email);
    _validateName(name);
  }

  // Constructor factory para crear usuarios con ID automática
  factory User.create({
    String? id,
    required String email,
    required String name,
    String? passwordHash,
    String? salt,
    String? token,
  }) {
    return User(
      id: id ?? const Uuid().v4(),
      email: email,
      name: name,
      passwordHash: passwordHash,
      salt: salt,
      token: token,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Validación de email
  void _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      throw FormatException('Invalid email format');
    }
  }

  // Validación de nombre (mínimo 2 caracteres, máximo 50)
  void _validateName(String name) {
    if (name.length < 2 || name.length > 50) {
      throw FormatException('Name must be between 2 and 50 characters');
    }
  }

  // Crear User desde un Map (para SQLite o API)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      passwordHash: map['passwordHash'] as String?,
      salt: map['salt'] as String?,
      token: map['token'] as String?,
      createdAt:
          map['createdAt'] != null
              ? DateTime.parse(map['createdAt'] as String)
              : null,
      updatedAt:
          map['updatedAt'] != null
              ? DateTime.parse(map['updatedAt'] as String)
              : null,
    );
  }

  // Convertir User a Map (para SQLite o API)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'passwordHash': passwordHash,
      'salt': salt,
      'token': token,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? passwordHash,
    String? salt,
    String? token,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
