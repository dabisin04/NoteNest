// ignore_for_file: depend_on_referenced_packages, use_build_context_synchronously

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_state.dart';
import 'package:temp/application/bloc/note/note_bloc.dart';
import 'package:temp/application/bloc/note/note_event.dart';
import 'package:temp/application/bloc/note/note_state.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class AddOrEditNoteScreen extends StatefulWidget {
  final Note? noteToEdit;

  const AddOrEditNoteScreen({super.key, this.noteToEdit});

  @override
  State<AddOrEditNoteScreen> createState() => _AddOrEditNoteScreenState();
}

class _AddOrEditNoteScreenState extends State<AddOrEditNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPublic = false;
  List<PlatformFile> _selectedFiles = [];
  List<Map<String, dynamic>> _existingFiles = [];

  @override
  void initState() {
    super.initState();
    final note = widget.noteToEdit;
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content ?? '';
      _isPublic = note.isPublic;
      _loadExistingFiles(note.id);
    }
    if (widget.noteToEdit != null) {
      context.read<NoteBloc>().add(GetNoteFiles(widget.noteToEdit!.id));
    }
  }

  Future<void> _loadExistingFiles(String noteId) async {
    final noteBloc = context.read<NoteBloc>();
    final repo = noteBloc.noteRepository;
    final files = await repo.getNoteFiles(noteId);
    setState(() => _existingFiles = files);
  }

  Future<void> _deleteExistingFile(String fileId) async {
    final noteBloc = context.read<NoteBloc>();
    final repo = noteBloc.noteRepository;
    await repo.deleteNoteFile(fileId);
    setState(() => _existingFiles.removeWhere((f) => f['id'] == fileId));
  }

  void _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt'
        ],
      );

      if (result != null) {
        final newFiles = result.files.where((newFile) {
          // Verificar si el archivo ya está seleccionado
          return !_selectedFiles.any((existingFile) =>
              existingFile.name == newFile.name &&
              existingFile.size == newFile.size);
        }).toList();

        if (newFiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Estos archivos ya han sido seleccionados')),
          );
          return;
        }

        final validFiles =
            newFiles.where((f) => f.size < 10 * 1024 * 1024).toList();

        if (validFiles.length != newFiles.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Algunos archivos superan los 10MB')),
          );
        }

        setState(() {
          _selectedFiles = [..._selectedFiles, ...validFiles];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar archivos: $e')),
      );
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _submit(User user) {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.noteToEdit != null;
    final noteId = isEditing ? widget.noteToEdit!.id : const Uuid().v4();

    final note = Note(
      id: noteId,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      isPublic: _isPublic,
      userId: user.id,
      createdAt: widget.noteToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      likes: widget.noteToEdit?.likes ?? 0,
    );

    final files = _selectedFiles.map((f) => File(f.path!)).toList();

    if (isEditing) {
      context.read<NoteBloc>().add(UpdateNoteConArchivos(note, files));
    } else {
      context.read<NoteBloc>().add(UploadNoteConArchivos(note, files));
    }

    Navigator.pop(context);
  }

  Widget _buildFilePreview(PlatformFile file, int index) {
    final ext = p.extension(file.path!).toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png'].contains(ext);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _getFileIcon(ext),
          size: 40,
          color: Colors.blueGrey,
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${(file.size / 1024).toStringAsFixed(2)} KB',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _removeSelectedFile(index),
        ),
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.jpg':
      case '.jpeg':
      case '.png':
        return Icons.image;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteToEdit != null ? 'Editar Nota' : 'Añadir Nota'),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthAuthenticated) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (value) =>
                        value == null || value.trim().length < 3
                            ? 'El título debe tener al menos 3 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Contenido de la nota',
                    ),
                    validator: (value) => value != null && value.length > 10000
                        ? 'La descripción no puede exceder los 10000 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Añadir Archivos (Opcional)'),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFiles.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Archivos seleccionados:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._selectedFiles
                        .asMap()
                        .entries
                        .map((e) => _buildFilePreview(e.value, e.key))
                        .toList(),
                  ],
                  if (_existingFiles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Archivos ya subidos:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._existingFiles.map((f) => ListTile(
                          leading: Icon(
                            _getFileIcon(f['fileUrl'] as String),
                            color: Colors.blueGrey,
                          ),
                          title: Text(f['fileUrl'] as String),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                _deleteExistingFile(f['id'] as String),
                          ),
                        )),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _isPublic,
                        onChanged: (val) => setState(() => _isPublic = val!),
                      ),
                      const Text('Nota pública')
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _submit(state.user),
                    child: Text(widget.noteToEdit != null
                        ? 'Guardar Cambios'
                        : 'Subir Nota'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
