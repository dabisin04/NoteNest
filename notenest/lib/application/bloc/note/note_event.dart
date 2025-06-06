import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:temp/domain/entities/note.dart';

abstract class NoteEvent extends Equatable {
  const NoteEvent();

  @override
  List<Object?> get props => [];
}

class UploadNote extends NoteEvent {
  final Note note;
  final List<File> files;

  const UploadNote(this.note, this.files);

  @override
  List<Object?> get props => [note, files];
}

class UploadNoteConArchivos extends NoteEvent {
  final Note note;
  final List<File> files;

  const UploadNoteConArchivos(this.note, this.files);

  @override
  List<Object?> get props => [note, files];
}

class UpdateNote extends NoteEvent {
  final Note note;

  const UpdateNote(this.note);

  @override
  List<Object?> get props => [note];
}

class UpdateNoteConArchivos extends NoteEvent {
  final Note note;
  final List<File> files;

  const UpdateNoteConArchivos(this.note, this.files);

  @override
  List<Object?> get props => [note, files];
}

class GetNoteFiles extends NoteEvent {
  final String noteId;
  const GetNoteFiles(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class DeleteNoteFile extends NoteEvent {
  final String fileId;
  const DeleteNoteFile(this.fileId);

  @override
  List<Object?> get props => [fileId];
}

class DownloadNote extends NoteEvent {
  final String noteId;

  const DownloadNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class DeleteNote extends NoteEvent {
  final String noteId;

  const DeleteNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class GetNotes extends NoteEvent {
  final bool onlyPublic;
  final String? userId;

  const GetNotes({this.onlyPublic = false, this.userId});

  @override
  List<Object?> get props => [onlyPublic, userId];
}

class SearchNotes extends NoteEvent {
  final String query;

  const SearchNotes(this.query);

  @override
  List<Object?> get props => [query];
}

class CacheNote extends NoteEvent {
  final Note note;

  const CacheNote(this.note);

  @override
  List<Object?> get props => [note];
}

class SyncNotes extends NoteEvent {}

class GetNoteAuthor extends NoteEvent {
  final String noteId;

  const GetNoteAuthor(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

class VerifyNoteAuthor extends NoteEvent {
  final String noteId;
  final String userId;

  const VerifyNoteAuthor(this.noteId, this.userId);

  @override
  List<Object?> get props => [noteId, userId];
}

class ClearNotes extends NoteEvent {
  const ClearNotes();
}
