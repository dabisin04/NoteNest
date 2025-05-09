import 'package:equatable/equatable.dart';
import 'package:temp/domain/entities/comment.dart';

abstract class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {}

class CommentLoading extends CommentState {}

class CommentPosted extends CommentState {
  final Comment comment;

  const CommentPosted(this.comment);

  @override
  List<Object?> get props => [comment];
}

class CommentReplied extends CommentState {
  final Comment reply;

  const CommentReplied(this.reply);

  @override
  List<Object?> get props => [reply];
}

class CommentEdited extends CommentState {
  final String commentId;
  final String newContent;

  const CommentEdited(this.commentId, this.newContent);

  @override
  List<Object?> get props => [commentId, newContent];
}

class CommentDeleted extends CommentState {
  final String commentId;

  const CommentDeleted(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class NoteLiked extends CommentState {
  final String noteId;

  const NoteLiked(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class NoteUnliked extends CommentState {
  final String noteId;
  NoteUnliked(this.noteId);
}

class CommentsLoaded extends CommentState {
  final List<Comment> comments;

  const CommentsLoaded(this.comments);

  @override
  List<Object?> get props => [comments];
}

class RepliesLoaded extends CommentState {
  final List<Comment> replies;

  const RepliesLoaded(this.replies);

  @override
  List<Object?> get props => [replies];
}

class CommentsSynced extends CommentState {}

class CommentError extends CommentState {
  final String message;

  const CommentError(this.message);

  @override
  List<Object?> get props => [message];
}
