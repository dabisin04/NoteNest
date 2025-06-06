// ignore_for_file: unused_element

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';
import 'package:temp/application/bloc/comment/comment_bloc.dart';
import 'package:temp/application/bloc/comment/comment_event.dart';
import 'package:temp/application/bloc/comment/comment_state.dart';
import 'package:temp/domain/entities/comment.dart';

enum NoteCommentMode { add, edit, reply }

class NoteCommentsModal extends StatefulWidget {
  final String noteId;
  const NoteCommentsModal({super.key, required this.noteId});

  @override
  _NoteCommentsModalState createState() => _NoteCommentsModalState();
}

class _NoteCommentsModalState extends State<NoteCommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  NoteCommentMode _mode = NoteCommentMode.add;
  String? _targetCommentId;

  @override
  void initState() {
    super.initState();
    context.read<CommentBloc>().add(GetComments(widget.noteId));
  }

  void _cancelMode() {
    setState(() {
      _mode = NoteCommentMode.add;
      _targetCommentId = null;
      _commentController.clear();
    });
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    if (_mode == NoteCommentMode.add) {
      context.read<CommentBloc>().add(CommentNote(Comment.create(
            noteId: widget.noteId,
            userId: authState.user.id,
            userName: authState.user.name,
            content: text,
          )));
    } else if (_mode == NoteCommentMode.edit && _targetCommentId != null) {
      context.read<CommentBloc>().add(EditComment(_targetCommentId!, text));
    } else if (_mode == NoteCommentMode.reply && _targetCommentId != null) {
      context.read<CommentBloc>().add(ReplyComment(Comment.create(
            noteId: widget.noteId,
            userId: authState.user.id,
            userName: authState.user.name,
            content: text,
            parentId: _targetCommentId,
          )));
    }

    _cancelMode();
  }

  String _formatDate(String iso) {
    try {
      return DateFormat("dd/MM/yy HH:mm").format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Widget _buildCommentTile(Comment c, {required bool isReply}) {
    final authState = context.read<AuthBloc>().state;
    final isAuthor =
        authState is AuthAuthenticated && authState.user.id == c.userId;

    return ListTile(
      contentPadding: EdgeInsets.only(left: isReply ? 32 : 16, right: 16),
      title: Text(
        '@${c.userName.isNotEmpty ? c.userName : c.userId.substring(0, 4)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(c.content),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'editar') {
            setState(() {
              _mode = NoteCommentMode.edit;
              _targetCommentId = c.id;
              _commentController.text = c.content;
            });
          } else if (value == 'responder') {
            setState(() {
              _mode = NoteCommentMode.reply;
              _targetCommentId = c.id;
              _commentController.clear();
            });
          } else if (value == 'eliminar') {
            context.read<CommentBloc>().add(DeleteComment(c.id));
          }
        },
        itemBuilder: (_) => [
          if (isAuthor)
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
          const PopupMenuItem(value: 'responder', child: Text('Responder')),
          if (isAuthor)
            const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
        ],
      ),
      dense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, __) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("Comentarios",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_mode != NoteCommentMode.add)
                    Row(
                      children: [
                        Text(
                            _mode == NoteCommentMode.edit
                                ? 'Editando'
                                : 'Respondiendo',
                            style: const TextStyle(color: Colors.blue)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _cancelMode,
                        )
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _submitComment,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: BlocListener<CommentBloc, CommentState>(
                      listener: (context, state) {
                        if (state is CommentPosted ||
                            state is CommentReplied ||
                            state is CommentEdited ||
                            state is CommentDeleted) {
                          context
                              .read<CommentBloc>()
                              .add(GetComments(widget.noteId));
                        }
                      },
                      child: BlocBuilder<CommentBloc, CommentState>(
                        builder: (_, state) {
                          if (state is CommentLoading) {
                            return const Center(
                                child: CircularProgressIndicator());
                          } else if (state is CommentsLoaded) {
                            final comments = state.comments;
                            final roots = comments
                                .where((c) => c.id == c.rootComment)
                                .toList();
                            final replies = comments
                                .where((c) => c.id != c.rootComment)
                                .toList();

                            return ListView(
                              controller: _scrollController,
                              children: roots.map((parent) {
                                final childReplies = replies
                                    .where((r) => r.rootComment == parent.id)
                                    .toList();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCommentTile(parent, isReply: false),
                                    ...childReplies.map((r) =>
                                        _buildCommentTile(r, isReply: true)),
                                  ],
                                );
                              }).toList(),
                            );
                          } else if (state is CommentError) {
                            return Center(
                              child: Text(
                                state.message,
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          } else {
                            return const Center(
                              child: Text("No hay comentarios aún."),
                            );
                          }
                        },
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        )
      ],
    );
  }
}
