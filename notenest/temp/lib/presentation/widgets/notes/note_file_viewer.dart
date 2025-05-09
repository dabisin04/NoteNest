// ignore_for_file: depend_on_referenced_packages, unused_import

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NoteFileViewer extends StatelessWidget {
  final String filePath;

  const NoteFileViewer({super.key, required this.filePath});

  Future<String> _resolveFullPath(String path) async {
    if (path.startsWith('/')) return path;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolveFullPath(filePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final fullPath = snapshot.data!;
        final file = File(fullPath);
        final mimeType = lookupMimeType(fullPath);
        final extension = p.extension(fullPath).toLowerCase();

        if (!file.existsSync()) {
          return const Text('Archivo no encontrado.');
        }

        if (mimeType?.startsWith('image/') == true) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
            ),
          );
        } else if (extension == '.txt') {
          return FutureBuilder<String>(
            future: file.readAsString(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: Text(
                  snapshot.data ?? 'No se pudo leer el archivo.',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            },
          );
        } else {
          return Container(
            height: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file,
                    size: 32, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p.basename(fullPath),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
