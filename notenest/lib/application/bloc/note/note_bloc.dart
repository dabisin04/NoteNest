import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:temp/domain/repositories/note_repository.dart';
import 'package:temp/application/bloc/note/note_event.dart';
import 'package:temp/application/bloc/note/note_state.dart';

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  final NoteRepository noteRepository;

  NoteBloc(this.noteRepository) : super(NoteInitial()) {
    on<UploadNote>(_onUploadNote);
    on<UploadNoteConArchivos>(_onUploadNoteConArchivos);
    on<UpdateNote>(_onUpdateNote);
    on<UpdateNoteConArchivos>(_onUpdateNoteConArchivos);
    on<GetNoteFiles>(_onGetNoteFiles);
    on<DeleteNoteFile>(_onDeleteNoteFile);
    on<DownloadNote>(_onDownloadNote);
    on<DeleteNote>(_onDeleteNote);
    on<GetNotes>(_onGetNotes);
    on<SearchNotes>(_onSearchNotes);
    on<CacheNote>(_onCacheNote);
    on<SyncNotes>(_onSyncNotes);
    on<GetNoteAuthor>(_onGetNoteAuthor);
    on<VerifyNoteAuthor>(_onVerifyNoteAuthor);
    on<ClearNotes>(_onClearNotes);
  }

  Future<void> _onUploadNote(UploadNote event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      await noteRepository.uploadNote(event.note, event.files);
      emit(NoteUploaded(event.note));

      // ✅ Cargar de nuevo todas las notas del usuario después de subir
      final notes = await noteRepository.getNotes(
        userId: event.note.userId,
        onlyPublic: false,
      );
      emit(NotesLoaded(notes));
    } catch (e, stackTrace) {
      debugPrint('Error en _onUploadNote: $e\n$stackTrace');
      emit(NoteError('Error al subir nota: $e'));
    }
  }

  Future<void> _onUploadNoteConArchivos(
    UploadNoteConArchivos event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      await noteRepository.uploadNoteWithFiles(event.note, event.files);
      emit(NoteUploaded(event.note));

      // ✅ Cargar nuevamente todas las notas del usuario
      final notes = await noteRepository.getNotes(
        userId: event.note.userId,
        onlyPublic: false,
      );
      emit(NotesLoaded(notes));
    } catch (e, stackTrace) {
      debugPrint('Error en _onUploadNoteConArchivos: $e\n$stackTrace');
      emit(NoteError('Error al subir nota con archivos: $e'));
    }
  }

  Future<void> _onUpdateNote(UpdateNote event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      await noteRepository.updateNote(event.note);
      emit(NoteUpdated(event.note));
      if (state is NotesLoaded) {
        final updatedNotes = (state as NotesLoaded).notes.map((n) {
          return n.id == event.note.id ? event.note : n;
        }).toList();
        emit(NotesLoaded(updatedNotes));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onUpdateNote: $e\n$stackTrace');
      emit(NoteError('Error al actualizar nota: $e'));
    }
  }

  Future<void> _onUpdateNoteConArchivos(
    UpdateNoteConArchivos event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      await noteRepository.updateNoteWithFiles(event.note, event.files);
      emit(NoteUpdated(event.note));
      if (state is NotesLoaded) {
        final updatedNotes = (state as NotesLoaded).notes.map((n) {
          return n.id == event.note.id ? event.note : n;
        }).toList();
        emit(NotesLoaded(updatedNotes));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onUpdateNoteConArchivos: $e\n$stackTrace');
      emit(NoteError('Error al actualizar nota con archivos: $e'));
    }
  }

  Future<void> _onGetNoteFiles(
    GetNoteFiles event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      final files = await noteRepository.getNoteFiles(event.noteId);
      emit(NoteFilesLoaded(files));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetNoteFiles: $e\n$stackTrace');
      emit(NoteError('Error al obtener archivos de la nota'));
    }
  }

  Future<void> _onDeleteNoteFile(
    DeleteNoteFile event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      await noteRepository.deleteNoteFile(event.fileId);
      emit(NoteFileDeleted(event.fileId));
    } catch (e, stackTrace) {
      debugPrint('Error en _onDeleteNoteFile: $e\n$stackTrace');
      emit(NoteError('Error al eliminar archivo de la nota'));
    }
  }

  Future<void> _onDownloadNote(
    DownloadNote event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      await noteRepository.downloadNote(event.noteId);
      final note = (await noteRepository.getNotes()).firstWhere(
        (n) => n.id == event.noteId,
      );
      emit(NoteDownloaded(note));
    } catch (e, stackTrace) {
      debugPrint('Error en _onDownloadNote: $e\n$stackTrace');
      emit(NoteError('Error al descargar nota: $e'));
    }
  }

  Future<void> _onDeleteNote(DeleteNote event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      await noteRepository.deleteNote(event.noteId);
      emit(NoteDeleted(event.noteId));
      if (state is NotesLoaded) {
        final updatedNotes = (state as NotesLoaded)
            .notes
            .where((note) => note.id != event.noteId)
            .toList();
        emit(NotesLoaded(updatedNotes));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onDeleteNote: $e\n$stackTrace');
      emit(NoteError('Error al eliminar nota: $e'));
    }
  }

  Future<void> _onGetNotes(GetNotes event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      final notes = await noteRepository.getNotes(
        onlyPublic: event.onlyPublic,
        userId: event.userId,
      );
      emit(NotesLoaded(notes));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetNotes: $e\n$stackTrace');
      emit(NoteError('Error al obtener notas: $e'));
    }
  }

  Future<void> _onSearchNotes(
    SearchNotes event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      final notes = await noteRepository.searchNotes(event.query);
      emit(NotesLoaded(notes));
    } catch (e, stackTrace) {
      debugPrint('Error en _onSearchNotes: $e\n$stackTrace');
      emit(NoteError('Error al buscar notas: $e'));
    }
  }

  Future<void> _onCacheNote(CacheNote event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      await noteRepository.cacheNote(event.note);
      emit(NoteCached(event.note));
    } catch (e, stackTrace) {
      debugPrint('Error en _onCacheNote: $e\n$stackTrace');
      emit(NoteError('Error al almacenar nota en caché: $e'));
    }
  }

  Future<void> _onSyncNotes(SyncNotes event, Emitter<NoteState> emit) async {
    emit(NoteLoading());
    try {
      await noteRepository.syncNotes();
      emit(NotesSynced());
      final notes = await noteRepository.getNotes();
      emit(NotesLoaded(notes));
    } catch (e, stackTrace) {
      debugPrint('Error en _onSyncNotes: $e\n$stackTrace');
      emit(NoteError('Error al sincronizar notas: $e'));
    }
  }

  Future<void> _onGetNoteAuthor(
    GetNoteAuthor event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      final author = await noteRepository.getNoteAuthor(event.noteId);
      emit(NoteAuthorFound(author));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetNoteAuthor: $e\n$stackTrace');
      emit(NoteError('Error al obtener autor de la nota: $e'));
    }
  }

  Future<void> _onVerifyNoteAuthor(
    VerifyNoteAuthor event,
    Emitter<NoteState> emit,
  ) async {
    emit(NoteLoading());
    try {
      final isAuthor = await noteRepository.verifyNoteAuthor(
        event.noteId,
        event.userId,
      );
      emit(NoteAuthorVerified(isAuthor));
    } catch (e, stackTrace) {
      debugPrint('Error en _onVerifyNoteAuthor: $e\n$stackTrace');
      emit(NoteError('Error al verificar autor de la nota: $e'));
    }
  }

  void _onClearNotes(ClearNotes event, Emitter<NoteState> emit) {
    emit(NoteInitial());
  }
}
