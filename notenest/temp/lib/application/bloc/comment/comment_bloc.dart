import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:temp/domain/entities/comment.dart';
import 'package:temp/domain/repositories/comment_repository.dart';
import 'package:temp/application/bloc/comment/comment_event.dart';
import 'package:temp/application/bloc/comment/comment_state.dart';
import 'package:temp/infrastructure/utils/shared_prefs_helper.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final CommentRepository commentRepository;

  CommentBloc(this.commentRepository) : super(CommentInitial()) {
    on<CommentNote>(_onCommentNote);
    on<ReplyComment>(_onReplyComment);
    on<EditComment>(_onEditComment);
    on<DeleteComment>(_onDeleteComment);
    on<LikeNote>(_onLikeNote);
    on<UnlikeNote>(_onUnlikeNote);
    on<GetComments>(_onGetComments);
    on<GetReplies>(_onGetReplies);
    on<SyncComments>(_onSyncComments);
  }

  Future<void> _onCommentNote(
    CommentNote event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.commentNote(event.comment);
      emit(CommentPosted(event.comment));
      if (state is CommentsLoaded) {
        final updatedComments = [
          ...(state as CommentsLoaded).comments,
          event.comment,
        ];
        emit(CommentsLoaded(updatedComments));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onCommentNote: $e\n$stackTrace');
      emit(CommentError('Error al comentar nota: $e'));
    }
  }

  Future<void> _onReplyComment(
    ReplyComment event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.replyComment(event.reply);
      emit(CommentReplied(event.reply));
      if (state is RepliesLoaded &&
          (state as RepliesLoaded).replies.any(
                (r) => r.parentId == event.reply.parentId,
              )) {
        final updatedReplies = [
          ...(state as RepliesLoaded).replies,
          event.reply,
        ];
        emit(RepliesLoaded(updatedReplies));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onReplyComment: $e\n$stackTrace');
      emit(CommentError('Error al responder comentario: $e'));
    }
  }

  Future<void> _onEditComment(
    EditComment event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.editComment(event.commentId, event.newContent);
      emit(CommentEdited(event.commentId, event.newContent));
      if (state is CommentsLoaded) {
        final updatedComments =
            (state as CommentsLoaded).comments.map((comment) {
          return comment.id == event.commentId
              ? comment.copyWith(content: event.newContent)
              : comment;
        }).toList();
        emit(CommentsLoaded(updatedComments));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onEditComment: $e\n$stackTrace');
      emit(CommentError('Error al editar comentario: $e'));
    }
  }

  Future<void> _onDeleteComment(
    DeleteComment event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.deleteComment(event.commentId);
      emit(CommentDeleted(event.commentId));
      if (state is CommentsLoaded) {
        final updatedComments = (state as CommentsLoaded)
            .comments
            .where((comment) => comment.id != event.commentId)
            .toList();
        emit(CommentsLoaded(updatedComments));
      }
      if (state is RepliesLoaded) {
        final updatedReplies = (state as RepliesLoaded)
            .replies
            .where((reply) => reply.id != event.commentId)
            .toList();
        emit(RepliesLoaded(updatedReplies));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onDeleteComment: $e\n$stackTrace');
      emit(CommentError('Error al eliminar comentario: $e'));
    }
  }

  Future<void> _onLikeNote(
    LikeNote event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.likeNote(event.noteId);
      emit(NoteLiked(event.noteId));
    } catch (e, stackTrace) {
      debugPrint('Error en _onLikeNote: $e\n$stackTrace');
      emit(CommentError('Error al dar like a la nota: $e'));
    }
  }

  Future<void> _onUnlikeNote(
    UnlikeNote event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.unlikeNote(event.noteId);
      emit(NoteUnliked(event.noteId));
    } catch (e, stackTrace) {
      debugPrint('Error en _onUnlikeNote: $e\n$stackTrace');
      emit(CommentError('Error al quitar like a la nota: $e'));
    }
  }

  Future<void> _onGetComments(
    GetComments event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      final comments = await commentRepository.getComments(event.noteId);
      emit(CommentsLoaded(comments));
      await SharedPrefsService.instance.setString(
        'comments_${event.noteId}',
        jsonEncode(comments.map((c) => c.toMap()).toList()),
      );
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetComments: $e\n$stackTrace');
      final cached =
          SharedPrefsService.instance.getString('comments_${event.noteId}');
      if (cached != null) {
        final parsed = (jsonDecode(cached) as List)
            .map((c) => Comment.fromMap(c))
            .toList();
        emit(CommentsLoaded(parsed));
      } else {
        emit(CommentError('Error al obtener comentarios: $e'));
      }
    }
  }

  Future<void> _onGetReplies(
    GetReplies event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      final replies = await commentRepository.getReplies(event.commentId);
      emit(RepliesLoaded(replies));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetReplies: $e\n$stackTrace');
      emit(CommentError('Error al obtener respuestas: $e'));
    }
  }

  Future<void> _onSyncComments(
    SyncComments event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    try {
      await commentRepository.syncComments();
      emit(CommentsSynced());
      if (state is CommentsLoaded &&
          (state as CommentsLoaded).comments.isNotEmpty) {
        final noteId = (state as CommentsLoaded).comments.first.noteId;
        final comments = await commentRepository.getComments(noteId);
        emit(CommentsLoaded(comments));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onSyncComments: $e\n$stackTrace');
      emit(CommentError('Error al sincronizar comentarios: $e'));
    }
  }
}

extension CommentExtension on Comment {
  Comment copyWith({String? content}) {
    return Comment(
      id: id,
      noteId: noteId,
      userId: userId,
      userName: userName,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      parentId: parentId,
      rootComment: rootComment,
    );
  }
}
