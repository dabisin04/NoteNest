import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:temp/domain/repositories/auth_repository.dart';
import 'package:temp/application/bloc/auth/auth_event.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc(this.authRepository) : super(AuthInitial()) {
    on<RegisterUser>(_onRegisterUser);
    on<LoginUser>(_onLoginUser);
    on<LogoutUser>(_onLogoutUser);
    on<LoadCurrentUser>(_onLoadCurrentUser);
    on<LoadCurrentSession>(_onLoadCurrentSession);
    on<SearchUsersByName>(_onSearchUsersByName);
    on<GetUserById>(_onGetUserById);
  }

  Future<void> _onRegisterUser(
    RegisterUser event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    debugPrint("🔐 Iniciando registro de usuario...");
    debugPrint("📧 Email: ${event.email}");
    debugPrint("👤 Nombre: ${event.name}");
    try {
      final user = await authRepository.register(
        event.email,
        event.password,
        event.name,
      );
      debugPrint("✅ Usuario registrado: ${user.id}");

      // 🔄 Intentar obtener sesión después del registro
      final session = await authRepository.getCurrentSession();
      if (session != null) {
        debugPrint("✅ Sesión iniciada correctamente: ${session.token}");
        emit(AuthAuthenticated(user, session));
      } else {
        debugPrint("⚠️ Sesión no creada después del registro");
        emit(AuthError('Sesión no creada después del registro'));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en _onRegisterUser: $e');
      debugPrint(stackTrace.toString());
      emit(AuthError('Error al registrar usuario: $e'));
    }
  }

  Future<void> _onLoginUser(LoginUser event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.email, event.password);
      final session = await authRepository.getCurrentSession();
      if (session != null) {
        emit(AuthAuthenticated(user, session));
      } else {
        emit(AuthError('Sesión no creada después del login'));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onLoginUser: $e\n$stackTrace');
      emit(AuthError('Error al iniciar sesión: $e'));
    }
  }

  Future<void> _onLogoutUser(LogoutUser event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await authRepository.logout();
      emit(AuthUnauthenticated());
    } catch (e, stackTrace) {
      debugPrint('Error en _onLogoutUser: $e\n$stackTrace');
      emit(AuthError('Error al cerrar sesión: $e'));
    }
  }

  Future<void> _onLoadCurrentUser(
    LoadCurrentUser event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      final session = await authRepository.getCurrentSession();
      if (user != null && session != null) {
        emit(AuthAuthenticated(user, session));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onLoadCurrentUser: $e\n$stackTrace');
      emit(AuthError('Error al cargar usuario actual: $e'));
    }
  }

  Future<void> _onLoadCurrentSession(
    LoadCurrentSession event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final session = await authRepository.getCurrentSession();
      if (session != null) {
        final user = await authRepository.getCurrentUser();
        if (user != null) {
          emit(AuthAuthenticated(user, session));
        } else {
          emit(AuthError('Usuario no encontrado para sesión actual'));
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onLoadCurrentSession: $e\n$stackTrace');
      emit(AuthError('Error al cargar sesión actual: $e'));
    }
  }

  Future<void> _onSearchUsersByName(
    SearchUsersByName event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final users = await authRepository.getUserByName(event.name);
      emit(AuthUsersLoaded(users));
    } catch (e, stackTrace) {
      debugPrint('Error en _onSearchUsersByName: $e\n$stackTrace');
      emit(AuthError('Error al buscar usuarios por nombre: $e'));
    }
  }

  Future<void> _onGetUserById(
    GetUserById event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getUserById(event.userId);
      if (user != null) {
        emit(AuthUserFound(user));
      } else {
        emit(AuthError('Usuario no encontrado'));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetUserById: $e\n$stackTrace');
      emit(AuthError('Error al obtener usuario por ID: $e'));
    }
  }
}
