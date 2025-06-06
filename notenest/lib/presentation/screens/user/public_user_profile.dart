// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/presentation/widgets/user/user_profile_header.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';
import 'package:temp/application/bloc/note/note_bloc.dart';
import 'package:temp/application/bloc/note/note_event.dart';
import 'package:temp/application/bloc/note/note_state.dart';
import 'package:temp/presentation/widgets/notes/note_card.dart';

class PublicProfileScreen extends StatefulWidget {
  final User user;

  const PublicProfileScreen({super.key, required this.user});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.id == widget.user.id) {
      // Redirigir al perfil propio si es el mismo usuario
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/profile');
      });
    } else {
      // Cargar notas públicas si es otro usuario
      context
          .read<NoteBloc>()
          .add(GetNotes(onlyPublic: true, userId: widget.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.user.name}')),
      body: Column(
        children: [
          UserProfileHeader(user: widget.user),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Notas públicas",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BlocBuilder<NoteBloc, NoteState>(
              builder: (context, state) {
                if (state is NoteLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is NotesLoaded) {
                  final notes = state.notes;
                  if (notes.isEmpty) {
                    return const Center(
                      child: Text('Este usuario no tiene notas públicas.'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<NoteBloc>().add(
                          GetNotes(onlyPublic: true, userId: widget.user.id));
                    },
                    child: ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return NoteCard(
                          note: note,
                          onTap: () {
                            context.read<NoteBloc>().add(GetNoteFiles(note.id));
                            Navigator.pushNamed(
                              context,
                              '/note_detail',
                              arguments: {'note': note},
                            );
                          },
                        );
                      },
                    ),
                  );
                } else if (state is NoteError) {
                  return Center(child: Text(state.message));
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
