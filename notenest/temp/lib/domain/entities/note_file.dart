import 'package:uuid/uuid.dart';

class NoteFile {
  final String id;
  final String noteId;
  final String fileUrl;

  NoteFile({
    required this.id,
    required this.noteId,
    required this.fileUrl,
  });

  factory NoteFile.create({required String noteId, required String fileUrl}) {
    return NoteFile(
      id: const Uuid().v4(),
      noteId: noteId,
      fileUrl: fileUrl,
    );
  }

  factory NoteFile.fromMap(Map<String, dynamic> map) {
    return NoteFile(
      id: map['id'],
      noteId: map['noteId'],
      fileUrl: map['fileUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'fileUrl': fileUrl,
    };
  }
}
