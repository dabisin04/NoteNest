import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';
import 'package:temp/application/bloc/note/note_bloc.dart';
import 'package:temp/application/bloc/note/note_event.dart';
import 'package:temp/application/bloc/note/note_state.dart';
import 'package:temp/presentation/widgets/notes/note_card.dart';
import 'package:temp/presentation/widgets/user/user_profile_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      print(
          '👤 [ProfileScreen] Obteniendo notas para usuario: ${authState.user.id}');
      context
          .read<NoteBloc>()
          .add(GetNotes(userId: authState.user.id, onlyPublic: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Limpiar el estado al salir
        context.read<NoteBloc>().add(ClearNotes());
        return true;
      },
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/create_note'),
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            if (authState is! AuthAuthenticated) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                UserProfileHeader(user: authState.user),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Mis notas",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<NoteBloc, NoteState>(
                    builder: (context, state) {
                      print('📝 [ProfileScreen] Estado actual: $state');
                      if (state is NoteLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is NotesLoaded) {
                        final notes = state.notes;
                        print(
                            '📝 [ProfileScreen] Notas cargadas: ${notes.length}');
                        if (notes.isEmpty) {
                          return const Center(
                              child: Text('Aún no tienes notas.'));
                        }
                        return RefreshIndicator(
                          onRefresh: () async {
                            _loadNotes();
                          },
                          child: ListView.builder(
                            itemCount: notes.length,
                            itemBuilder: (_, index) {
                              final note = notes[index];
                              print(
                                  '📝 [ProfileScreen] Mostrando nota: ${note.id}');
                              return NoteCard(
                                note: note,
                                onTap: () async {
                                  context
                                      .read<NoteBloc>()
                                      .add(GetNoteFiles(note.id));
                                  await Navigator.pushNamed(
                                    context,
                                    '/note_detail',
                                    arguments: {'note': note},
                                  );
                                  // Recargar notas al volver
                                  _loadNotes();
                                },
                              );
                            },
                          ),
                        );
                      } else {
                        return const Center(
                            child: Text('Error al cargar tus notas.'));
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
