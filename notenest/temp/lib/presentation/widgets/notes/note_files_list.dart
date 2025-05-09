// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NoteFilesList extends StatelessWidget {
  final List<String> filePaths;

  const NoteFilesList({super.key, required this.filePaths});

  Future<String> _resolveFullPath(String path) async {
    if (path.startsWith('/')) return path;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, path);
  }

  void _openFile(BuildContext context, String path) async {
    final fullPath = await _resolveFullPath(path);
    final result = await OpenFile.open(fullPath);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el archivo: $path')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (filePaths.isEmpty) {
      return const Text("No hay archivos adjuntos");
    }

    return FutureBuilder<List<String>>(
      future: Future.wait(filePaths.map(_resolveFullPath)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final resolvedPaths = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: resolvedPaths.map((fullPath) {
            final ext = p.extension(fullPath).toLowerCase();
            final icon = _getIcon(ext);
            return ListTile(
              leading: Icon(icon, color: Colors.blueGrey),
              title: Text(p.basename(fullPath)),
              trailing: IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () => _openFile(context, fullPath),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  IconData _getIcon(String ext) {
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
}
