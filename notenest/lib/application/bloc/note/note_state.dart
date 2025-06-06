import 'package:equatable/equatable.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/domain/entities/user.dart';

abstract class NoteState extends Equatable {
  const NoteState();

  @override
  List<Object?> get props => [];
}

class NoteInitial extends NoteState {}

class NoteLoading extends NoteState {}

class NoteUploaded extends NoteState {
  final Note note;

  const NoteUploaded(this.note);

  @override
  List<Object?> get props => [note];
}

class NoteUpdated extends NoteState {
  final Note note;
  NoteUpdated(this.note);
}

class NoteFilesLoaded extends NoteState {
  final List<Map<String, dynamic>> files;
  const NoteFilesLoaded(this.files);

  @override
  List<Object?> get props => [files];
}

class NoteFileDeleted extends NoteState {
  final String fileId;
  const NoteFileDeleted(this.fileId);

  @override
  List<Object?> get props => [fileId];
}

class NoteDownloaded extends NoteState {
  final Note note;

  const NoteDownloaded(this.note);

  @override
  List<Object?> get props => [note];
}

class NoteDeleted extends NoteState {
  final String noteId;

  const NoteDeleted(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class NotesLoaded extends NoteState {
  final List<Note> notes;

  const NotesLoaded(this.notes);

  @override
  List<Object?> get props => [notes];
}

class NoteAuthorFound extends NoteState {
  final User author;

  const NoteAuthorFound(this.author);

  @override
  List<Object?> get props => [author];
}

class NoteAuthorVerified extends NoteState {
  final bool isAuthor;

  const NoteAuthorVerified(this.isAuthor);

  @override
  List<Object?> get props => [isAuthor];
}

class NotesSynced extends NoteState {}

class NoteCached extends NoteState {
  final Note note;

  const NoteCached(this.note);

  @override
  List<Object?> get props => [note];
}

class NoteError extends NoteState {
  final String message;

  const NoteError(this.message);

  @override
  List<Object?> get props => [message];
}
