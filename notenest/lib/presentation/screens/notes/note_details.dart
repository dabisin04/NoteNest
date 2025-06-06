// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';
import 'package:temp/application/bloc/comment/comment_bloc.dart';
import 'package:temp/application/bloc/comment/comment_event.dart';
import 'package:temp/application/bloc/note/note_bloc.dart';
import 'package:temp/application/bloc/note/note_event.dart';
import 'package:temp/application/bloc/note/note_state.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:temp/presentation/widgets/comments/note_comments_modal.dart';
import 'package:temp/presentation/widgets/notes/author_edit_button.dart';
import 'package:temp/presentation/widgets/notes/like_button.dart';
import 'package:temp/presentation/widgets/notes/note_file_viewer.dart';
import 'package:temp/presentation/widgets/notes/note_files_list.dart';
import 'package:file_picker/file_picker.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NoteBloc>().add(GetNoteFiles(widget.note.id));
    context.read<NoteBloc>().add(GetNoteAuthor(widget.note.id));
  }

  void _goToAuthorProfile(BuildContext context, User author) {
    Navigator.pushNamed(
      context,
      '/public_profile',
      arguments: author,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note.title),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated &&
                  state.user.id == widget.note.userId) {
                return AuthorEditButton(
                  note: widget.note,
                  onEdit: () {
                    Navigator.pushNamed(
                      context,
                      '/edit_note',
                      arguments: widget.note,
                    );
                  },
                );
              }
              return const SizedBox();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.note.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            BlocBuilder<NoteBloc, NoteState>(
              builder: (context, state) {
                if (state is NoteAuthorFound) {
                  return GestureDetector(
                    onTap: () => _goToAuthorProfile(context, state.author),
                    child: Text(
                      '@${state.author.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 8),
            if (widget.note.content != null && widget.note.content!.isNotEmpty)
              Text(
                widget.note.content!,
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 16),
            BlocBuilder<NoteBloc, NoteState>(
              builder: (context, state) {
                if (state is NoteFilesLoaded && state.files.isNotEmpty) {
                  final paths =
                      state.files.map((f) => f['fileUrl'] as String).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Archivos adjuntos:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: paths.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () {
                              OpenFile.open(paths[index]);
                            },
                            child: NoteFileViewer(filePath: paths[index]),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      NoteFilesList(filePaths: paths),
                    ],
                  );
                }
                return const Text("Sin archivos adjuntos.");
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NoteLikeButton(note: widget.note),
                TextButton.icon(
                  icon: const Icon(Icons.comment),
                  label: const Text("Comentarios"),
                  onPressed: () {
                    context
                        .read<CommentBloc>()
                        .add(GetComments(widget.note.id));
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => NoteCommentsModal(noteId: widget.note.id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
