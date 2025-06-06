import 'dart:io';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/domain/entities/user.dart';

abstract class NoteRepository {
  Future<void> uploadNote(Note note, List<File> files);
  Future<void> uploadNoteWithFiles(Note note, List<File> files);
  Future<void> updateNote(Note updatedNote);
  Future<void> updateNoteWithFiles(Note updatedNote, List<File> newFiles);
  Future<void> downloadNote(String noteId);
  Future<void> deleteNote(String noteId);
  Future<List<Note>> getNotes({bool onlyPublic = false, String? userId});
  Future<List<Note>> searchNotes(String query);
  Future<void> cacheNote(Note note);
  Future<void> syncNotes();
  Future<User> getNoteAuthor(String noteId);
  Future<bool> verifyNoteAuthor(String noteId, String userId);
  Future<List<Map<String, dynamic>>> getNoteFiles(String noteId);
  Future<void> deleteNoteFile(String fileId);
}
