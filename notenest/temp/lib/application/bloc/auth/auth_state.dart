import 'package:equatable/equatable.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:temp/domain/entities/session.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final Session session;

  const AuthAuthenticated(this.user, this.session);

  @override
  List<Object?> get props => [user, session];
}

class AuthUnauthenticated extends AuthState {}

class AuthUsersLoaded extends AuthState {
  final List<User> users;

  const AuthUsersLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class AuthUserFound extends AuthState {
  final User user;

  const AuthUserFound(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'AuthError: $message';
}
