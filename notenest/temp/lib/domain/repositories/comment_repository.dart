import 'package:temp/domain/entities/comment.dart';

abstract class CommentRepository {
  Future<void> commentNote(Comment comment);
  Future<void> replyComment(Comment reply);
  Future<void> editComment(String commentId, String newContent);
  Future<void> deleteComment(String commentId);
  Future<void> likeNote(String noteId);
  Future<List<Comment>> getComments(String noteId);
  Future<List<Comment>> getReplies(String commentId);
  Future<void> syncComments();
  Future<void> unlikeNote(String noteId);
}
