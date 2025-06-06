import 'package:equatable/equatable.dart';
import 'package:temp/domain/entities/comment.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object?> get props => [];
}

class CommentNote extends CommentEvent {
  final Comment comment;

  const CommentNote(this.comment);

  @override
  List<Object?> get props => [comment];
}

class ReplyComment extends CommentEvent {
  final Comment reply;

  const ReplyComment(this.reply);

  @override
  List<Object?> get props => [reply];
}

class EditComment extends CommentEvent {
  final String commentId;
  final String newContent;

  const EditComment(this.commentId, this.newContent);

  @override
  List<Object?> get props => [commentId, newContent];
}

class DeleteComment extends CommentEvent {
  final String commentId;

  const DeleteComment(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class LikeNote extends CommentEvent {
  final String noteId;

  const LikeNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class UnlikeNote extends CommentEvent {
  final String noteId;

  const UnlikeNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class GetComments extends CommentEvent {
  final String noteId;

  const GetComments(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class GetReplies extends CommentEvent {
  final String commentId;

  const GetReplies(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class SyncComments extends CommentEvent {
  const SyncComments();

  @override
  List<Object?> get props => [];
}
