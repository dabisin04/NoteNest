import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class RegisterUser extends AuthEvent {
  final String email;
  final String password;
  final String name;

  const RegisterUser(this.email, this.password, this.name);

  @override
  List<Object?> get props => [email, password, name];
}

class LoginUser extends AuthEvent {
  final String email;
  final String password;

  const LoginUser(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

class LogoutUser extends AuthEvent {}

class LoadCurrentUser extends AuthEvent {}

class LoadCurrentSession extends AuthEvent {}

class SearchUsersByName extends AuthEvent {
  final String name;

  const SearchUsersByName(this.name);

  @override
  List<Object?> get props => [name];
}

class GetUserById extends AuthEvent {
  final String userId;

  const GetUserById(this.userId);

  @override
  List<Object?> get props => [userId];
}
