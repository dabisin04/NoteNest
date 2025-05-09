import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';
import 'package:temp/domain/entities/note.dart';

class AuthorEditButton extends StatelessWidget {
  final Note note;
  final VoidCallback onEdit;

  const AuthorEditButton({super.key, required this.note, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    if (state is AuthAuthenticated && state.user.id == note.userId) {
      return IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onEdit,
      );
    }
    return const SizedBox.shrink();
  }
}
