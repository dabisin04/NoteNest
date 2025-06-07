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

/// Implementación del repositorio de autenticación que maneja la persistencia y sincronización
/// de usuarios y sesiones entre el almacenamiento local (SQLite) y el servidor remoto.
///
/// Esta clase implementa la interfaz AuthRepository y proporciona funcionalidad para:
/// - Registro e inicio de sesión de usuarios
/// - Gestión de sesiones y tokens
/// - Encriptación y verificación de contraseñas
/// - Sincronización de datos entre el almacenamiento local y el servidor
class AuthRepositoryImpl implements AuthRepository {
  final String _baseUrl = ApiConstants.baseUrl;
  final _uuid = Uuid();

  /// Obtiene la instancia de la base de datos SQLite
  Future<Database> get _db async => await SQLiteService.instance;

  /// Genera un salt aleatorio para la encriptación de contraseñas
  String _generateSalt() => _uuid.v4();

  /// Encripta una contraseña usando SHA-256 con salt
  ///
  /// [password] - Contraseña a encriptar
  /// [salt] - Salt para la encriptación
  /// Retorna el hash de la contraseña
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  /// Verifica si una contraseña coincide con su hash
  ///
  /// [password] - Contraseña a verificar
  /// [hashedPassword] - Hash almacenado
  /// [salt] - Salt usado en la encriptación
  /// Retorna true si la contraseña coincide, false en caso contrario
  bool _verifyPassword(String password, String hashedPassword, String salt) {
    return _hashPassword(password, salt) == hashedPassword;
  }

  /// Genera un token único para la sesión
  String _generateToken() => _uuid.v4();

  /// Verifica si hay conexión a internet intentando resolver google.com
  /// Retorna true si hay conexión, false en caso contrario
  Future<bool> _isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(ApiConstants.timeoutDuration);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Intenta realizar una petición POST a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
  /// [data] - Datos a enviar en el cuerpo de la petición
  /// Retorna la respuesta HTTP si fue exitosa, null en caso contrario
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

  /// Intenta realizar una petición GET a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
  /// Retorna la respuesta HTTP si fue exitosa, null en caso contrario
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

  /// Intenta realizar una petición DELETE a la API
  ///
  /// [endpoint] - Ruta del endpoint a llamar
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

  /// Registra un nuevo usuario en el sistema
  ///
  /// [email] - Email del usuario
  /// [password] - Contraseña del usuario
  /// [name] - Nombre del usuario
  /// Retorna el usuario creado
  @override
  Future<User> register(String email, String password, String name) async {
    final db = await _db;

    if (await _isOnline()) {
      final response = await _tryPostToApi('register', {
        'email': email,
        'password': password,
        'name': name,
      });

      // Si la respuesta es exitosa y no es nula, se obtiene el usuario del servidor
      if (response != null) {
        final data = json.decode(response.body);

        // Validación segura para evitar errores de null
        final String? salt = data['salt'];
        if (salt == null || salt.isEmpty) {
          throw Exception('Salt no recibido del backend');
        }

        // Se crea el usuario con los datos del servidor
        final user = User(
          id: data['id'],
          email: email,
          name: name,
          passwordHash: _hashPassword(password, salt),
          salt: salt,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Se inserta el usuario en la base de datos local
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

  /// Inicia sesión de un usuario existente
  ///
  /// [email] - Email del usuario
  /// [password] - Contraseña del usuario
  /// Retorna el usuario autenticado
  @override
  Future<User> login(String email, String password) async {
    final db = await _db;

    // Se busca el usuario en la base de datos local
    final localUsers =
        await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (localUsers.isNotEmpty) {
      // Se obtiene el usuario de la base de datos local
      final user = User.fromMap(localUsers.first);
      if (_verifyPassword(password, user.passwordHash!, user.salt!)) {
        // Se genera un token de sesión
        final token = _generateToken();
        await SessionService.saveUsuario(user);
        await SessionService.saveToken(token);
        await SessionService.saveExpiration(
            DateTime.now().add(const Duration(hours: 24)));
        return user;
      }
    }

    // Si no hay conexión a internet, se intenta iniciar sesión en el servidor
    if (await _isOnline()) {
      final response = await _tryPostToApi('login', {
        'email': email,
        'password': password,
      });

      // Si la respuesta es exitosa y no es nula, se obtiene el usuario del servidor
      if (response != null) {
        final data = json.decode(response.body);
        final user = User.fromMap(data['user']);

        // Se inserta el usuario en la base de datos local
        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        // Se crea una sesión en el servidor
        await _tryPostToApi('createSession', {
          'userId': user.id,
          'duration': 7,
        });

        // Se genera un token de sesión
        final token = _generateToken();

        // Se guarda la sesión en el almacenamiento local
        await SessionService.saveUsuario(user);
        await SessionService.saveToken(token);
        await SessionService.saveExpiration(
            DateTime.now().add(const Duration(hours: 24)));
        return user; // Se retorna el usuario autenticado
      }
    }

    // Si no hay conexión a internet, se lanza una excepción
    print("📲 [AuthRepository] Login con email: $email");
    throw Exception('Login failed: Invalid credentials or no connection');
  }

  /// Cierra la sesión del usuario actual
  /// Elimina la sesión tanto local como en el servidor
  @override
  Future<void> logout() async {
    // Se obtiene la sesión actual
    final session = await getCurrentSession();

    // Si hay conexión a internet y la sesión es válida, se elimina la sesión en el servidor
    if (await _isOnline() && session != null) {
      await _tryDeleteFromApi('deleteSession/${session.userId}');
    }

    // Se limpia la sesión en el almacenamiento local
    await SessionService.clearSession();
  }

  /// Obtiene el usuario actualmente autenticado
  /// Retorna el usuario si hay una sesión válida, null en caso contrario
  @override
  Future<User?> getCurrentUser() async {
    final db = await _db;

    // Se obtiene la sesión actual
    final session = await getCurrentSession();

    // Si la sesión es válida, se obtiene el usuario de la base de datos local
    if (session != null && session.isValid) {
      final userRows =
          await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
      if (userRows.isNotEmpty) return User.fromMap(userRows.first);
    }

    // Se obtiene el usuario de la sesión en el almacenamiento local
    final usuario = await SessionService.getUsuario();
    if (usuario != null) return usuario;

    // Si hay conexión a internet y la sesión es válida, se obtiene el usuario del servidor
    if (await _isOnline() && session != null) {
      final response = await _tryGetFromApi('users/me?token=${session.token}');
      if (response != null) {
        final user = User.fromMap(json.decode(response.body));

        // Se inserta el usuario en la base de datos local
        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);

        // Se guarda el usuario en la sesión en el almacenamiento local
        await SessionService.saveUsuario(user);
        return user;
      }
    }

    return null;
  }

  /// Obtiene la sesión actual del usuario
  /// Retorna la sesión si es válida, null en caso contrario
  @override
  Future<Session?> getCurrentSession() async {
    // Se obtiene el token de la sesión en el almacenamiento local
    final token = await SessionService.getToken();

    // Se obtiene el ID del usuario de la sesión en el almacenamiento local
    final userId = await SessionService.getUsuarioId();

    // Se obtiene la fecha de expiración de la sesión en el almacenamiento local
    final expiresAt = await SessionService.getExpiration();

    // Si el token, el ID del usuario y la fecha de expiración son válidos, se crea una sesión
    if (token != null && userId != null && expiresAt != null) {
      final session =
          Session(userId: userId, token: token, expiresAt: expiresAt);
      if (session.isValid) return session;
    }

    // Se limpia la sesión en el almacenamiento local
    await SessionService.clearTokenData();
    return null;
  }

  /// Busca usuarios por nombre
  ///
  /// [name] - Nombre o parte del nombre a buscar
  /// Retorna una lista de usuarios que coinciden con la búsqueda
  @override
  Future<List<User>> getUserByName(String name) async {
    final db = await _db;

    // Se obtiene la lista de usuarios de la base de datos local
    final maps =
        await db.query('users', where: 'name LIKE ?', whereArgs: ['%$name%']);
    final localUsers = maps.map((map) => User.fromMap(map)).toList();

    // Si hay conexión a internet, se obtiene la lista de usuarios del servidor
    if (await _isOnline()) {
      final response = await _tryGetFromApi('users?name=$name');
      if (response != null) {
        // Se obtiene la lista de usuarios del servidor
        final remoteUsers = (json.decode(response.body) as List)
            .map((map) => User.fromMap(map))
            .toList();

        // Se inserta cada usuario en la base de datos local
        for (var user in remoteUsers) {
          await db.insert('users', user.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Se retorna la lista de usuarios del servidor
        return remoteUsers;
      }
    }

    // Se retorna la lista de usuarios de la base de datos local
    return localUsers;
  }

  /// Obtiene un usuario específico por su ID
  ///
  /// [id] - ID del usuario a buscar
  /// Retorna el usuario si existe, null en caso contrario
  @override
  Future<User?> getUserById(String id) async {
    final db = await _db;

    // Se obtiene el usuario de la base de datos local
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);

    // Si el usuario existe, se retorna
    if (maps.isNotEmpty) return User.fromMap(maps.first);

    // Si hay conexión a internet, se obtiene el usuario del servidor
    if (await _isOnline()) {
      final response = await _tryGetFromApi('users/$id');
      if (response != null) {
        final user = User.fromMap(json.decode(response.body));

        // Se inserta el usuario en la base de datos local
        await db.insert('users', user.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        return user;
      }
    }

    // Se retorna null si el usuario no existe
    return null;
  }
}
