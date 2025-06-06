import 'package:temp/domain/entities/user.dart';
import 'package:temp/domain/entities/session.dart';

abstract class AuthRepository {
  Future<User> register(String email, String password, String name);
  Future<User> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<Session?> getCurrentSession();
  Future<List<User>> getUserByName(String name);
  Future<User?> getUserById(String id);
}
