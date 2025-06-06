import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:temp/core/constants/api_constants.dart';
import 'package:temp/core/services/sqlite_service.dart';
import 'package:temp/core/services/session_service.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:temp/domain/entities/session.dart';
import 'package:temp/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final String _baseUrl = ApiConstants.baseUrl;
  final _uuid = Uuid();

  Future<Database> get _db async => await SQLiteService.instance;

  String _generateSalt() => _uuid.v4();

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  bool _verifyPassword(String password, String hashedPassword, String salt) {
    return _hashPassword(password, salt) == hashedPassword;
  }

  String _generateToken() => _uuid.v4();

  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(ApiConstants.timeoutDuration);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response?> _tryPostToApi(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final sanitizedEndpoint =
          endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      final uri = Uri.parse('$_baseUrl$sanitizedEndpoint');
      print('📤 Enviando POST a: $uri');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(ApiConstants.timeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ POST: $sanitizedEndpoint');
        return response;
      } else {
        print('❌ POST fallo [$sanitizedEndpoint]: ${response.statusCode}');
        print(response.body);
      }
    } catch (e) {
      print('⏱️ POST error: $e');
    }
    return null;
  }

  Future<http.Response?> _tryGetFromApi(String endpoint) async {
    try {
      final sanitizedEndpoint =
          endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      final uri = Uri.parse('$_baseUrl$sanitizedEndpoint');
      print('🌐 Enviando GET a: $uri');

      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(ApiConstants.timeoutDuration);

      if (response.statusCode == 200) {
        print('✅ GET: $sanitizedEndpoint');
        return response;
      } else {
        print('❌ GET fallo [$sanitizedEndpoint]: ${response.statusCode}');
        print(response.body);
      }
    } catch (e) {
      print('⏱️ GET error: $e');
    }
    return null;
  }

  Future<void> _tryDeleteFromApi(String endpoint) async {
    try {
      final sanitizedEndpoint =
          endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      final uri = Uri.parse('$_baseUrl$sanitizedEndpoint');
      print('🗑️ Enviando DELETE a: $uri');

      final response = await http.delete(uri, headers: {
        'Content-Type': 'application/json'
      }).timeout(ApiConstants.timeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ DELETE: $sanitizedEndpoint');
      } else {
        print('❌ DELETE fallo [$sanitizedEndpoint]: ${response.statusCode}');
        print(response.body);
      }
    } catch (e) {
      print('⏱️ DELETE error: $e');
    }
  }

  @override
  Future<User> register(String email, String password, String name) async {
    final db = await _db;

    if (await _isOnline()) {
      final response = await _tryPostToApi('register', {
        'email': email,
        'password': password,
        'name': name,
      });

      if (response != null) {
        final data = json.decode(response.body);

        // Validación segura
        final String? salt = data['salt'];
        if (salt == null || salt.isEmpty) {
          throw Exception('Salt no recibido del backend');
        }

        final user = User(
          id: data['id'],
          email: email,
          name: name,
          passwordHash: _hashPassword(password, salt),
          salt: salt,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        print('🟢 Usuario registrado en servidor con ID: ${user.id}');
        print("📲 [AuthRepository] Registrando usuario con email: $email");
        return user;
      } else {
        throw Exception('Error al registrar en el servidor');
      }
    } else {
      final salt = _generateSalt();
      final passwordHash = _hashPassword(password, salt);
      final userId = _uuid.v4();

      final user = User(
        id: userId,
        email: email,
        name: name,
        passwordHash: passwordHash,
        salt: salt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.insert('users', user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      return user;
    }
  }

  @override
  Future<User> login(String email, String password) async {
    final db = await _db;

    final localUsers =
        await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (localUsers.isNotEmpty) {
      final user = User.fromMap(localUsers.first);
      if (_verifyPassword(password, user.passwordHash!, user.salt!)) {
        final token = _generateToken();
        await SessionService.saveUsuario(user);
        await SessionService.saveToken(token);
        await SessionService.saveExpiration(
            DateTime.now().add(const Duration(hours: 24)));
        return user;
      }
    }

    if (await _isOnline()) {
      final response = await _tryPostToApi('login', {
        'email': email,
        'password': password,
      });
      if (response != null) {
        final data = json.decode(response.body);
        final user = User.fromMap(data['user']);

        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        await _tryPostToApi('createSession', {
          'userId': user.id,
          'duration': 7,
        });

        final token = _generateToken();
        await SessionService.saveUsuario(user);
        await SessionService.saveToken(token);
        await SessionService.saveExpiration(
            DateTime.now().add(const Duration(hours: 24)));
        return user;
      }
    }

    print("📲 [AuthRepository] Login con email: $email");
    throw Exception('Login failed: Invalid credentials or no connection');
  }

  @override
  Future<void> logout() async {
    final session = await getCurrentSession();

    if (await _isOnline() && session != null) {
      await _tryDeleteFromApi('deleteSession/${session.userId}');
    }

    await SessionService.clearSession();
  }

  @override
  Future<User?> getCurrentUser() async {
    final db = await _db;
    final session = await getCurrentSession();

    if (session != null && session.isValid) {
      final userRows =
          await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
      if (userRows.isNotEmpty) return User.fromMap(userRows.first);
    }

    final usuario = await SessionService.getUsuario();
    if (usuario != null) return usuario;

    if (await _isOnline() && session != null) {
      final response = await _tryGetFromApi('users/me?token=${session.token}');
      if (response != null) {
        final user = User.fromMap(json.decode(response.body));
        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await SessionService.saveUsuario(user);
        return user;
      }
    }

    return null;
  }

  @override
  Future<Session?> getCurrentSession() async {
    final token = await SessionService.getToken();
    final userId = await SessionService.getUsuarioId();
    final expiresAt = await SessionService.getExpiration();

    if (token != null && userId != null && expiresAt != null) {
      final session =
          Session(userId: userId, token: token, expiresAt: expiresAt);
      if (session.isValid) return session;
    }

    await SessionService.clearTokenData();
    return null;
  }

  @override
  Future<List<User>> getUserByName(String name) async {
    final db = await _db;
    final maps =
        await db.query('users', where: 'name LIKE ?', whereArgs: ['%$name%']);
    final localUsers = maps.map((map) => User.fromMap(map)).toList();

    if (await _isOnline()) {
      final response = await _tryGetFromApi('users?name=$name');
      if (response != null) {
        final remoteUsers = (json.decode(response.body) as List)
            .map((map) => User.fromMap(map))
            .toList();
        for (var user in remoteUsers) {
          await db.insert('users', user.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        return remoteUsers;
      }
    }

    return localUsers;
  }

  @override
  Future<User?> getUserById(String id) async {
    final db = await _db;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) return User.fromMap(maps.first);

    if (await _isOnline()) {
      final response = await _tryGetFromApi('users/$id');
      if (response != null) {
        final user = User.fromMap(json.decode(response.body));
        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        return user;
      }
    }

    return null;
  }
}
