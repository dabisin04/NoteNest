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

  IconData _getFileIcon(String extension, String? mimeType) {
    extension = extension.toLowerCase();
    if (mimeType?.startsWith('image/') == true) return Icons.image;
    if (mimeType?.startsWith('video/') == true) return Icons.video_file;
    if (mimeType?.startsWith('audio/') == true) return Icons.audio_file;

    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.txt':
        return Icons.text_snippet;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildPreview(
      BuildContext context, File file, String? mimeType, String extension) {
    if (!file.existsSync()) {
      return _buildErrorPreview('Archivo no encontrado');
    }

    if (mimeType?.startsWith('image/') == true) {
      return _buildImagePreview(file);
    }

    return _buildGenericPreview(file, mimeType, extension);
  }

  Widget _buildErrorPreview(String message) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 32, color: Colors.red[300]),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[300]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(File file) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPreview('Error al cargar la imagen');
          },
        ),
      ),
    );
  }

  Widget _buildGenericPreview(File file, String? mimeType, String extension) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(extension, mimeType),
            size: 40,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 8),
          Text(
            p.basename(file.path),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            extension.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

        return _buildPreview(context, file, mimeType, extension);
      },
    );
  }
}
