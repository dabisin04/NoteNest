// ignore_for_file: depend_on_referenced_packages

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class SQLiteService {
  static Database? _database;
  static const String _databaseName = 'notenest.db';
  static const int _databaseVersion = 4; // Incrementado para forzar onUpgrade

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      passwordHash TEXT,
      salt TEXT,
      token TEXT,
      createdAt TEXT,
      updatedAt TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE sessions (
      id TEXT PRIMARY KEY,
      userId TEXT NOT NULL,
      token TEXT NOT NULL,
      expiresAt TEXT NOT NULL,
      createdAt TEXT,
      updatedAt TEXT,
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    CREATE TABLE notes (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      content TEXT,
      isPublic INTEGER NOT NULL,
      userId TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      likes INTEGER NOT NULL,
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    CREATE TABLE note_files (
      id TEXT PRIMARY KEY,
      noteId TEXT NOT NULL,
      fileUrl TEXT NOT NULL,
      FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    CREATE TABLE comments (
      id TEXT PRIMARY KEY,
      noteId TEXT NOT NULL,
      userId TEXT NOT NULL,
      userName TEXT NOT NULL,
      content TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      parentId TEXT,
      rootComment TEXT,
      FOREIGN KEY (noteId) REFERENCES notes(id) ON DELETE CASCADE,
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (parentId) REFERENCES comments(id) ON DELETE CASCADE,
      FOREIGN KEY (rootComment) REFERENCES comments(id) ON DELETE CASCADE
    )
  ''');

    // Índices
    await db.execute('CREATE INDEX idx_notes_userId ON notes(userId)');
    await db.execute('CREATE INDEX idx_comments_noteId ON comments(noteId)');
    await db.execute(
        'CREATE INDEX idx_comments_rootComment ON comments(rootComment)');
    await db
        .execute('CREATE INDEX idx_comments_parentId ON comments(parentId)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final tableInfo = await db.rawQuery("PRAGMA table_info(comments)");
      final columnNames = tableInfo.map((e) => e['name']).toSet();

      if (!columnNames.contains('userName')) {
        await db.execute(
            'ALTER TABLE comments ADD COLUMN userName TEXT NOT NULL DEFAULT "Usuario"');
        print('🛠️ Columna userName agregada a comments');
      }
    }
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
