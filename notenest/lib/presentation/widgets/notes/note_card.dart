// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/presentation/widgets/notes/note_file_viewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteCard({super.key, required this.note, this.onTap});

  IconData _getFileIcon(String path) {
    final ext = p.extension(path).toLowerCase();
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
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (note.content != null && note.content!.isNotEmpty)
                Text(
                  note.content!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(height: 8),
              FutureBuilder<List<File>>(
                future: _getPreviewFiles(note.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final file = snapshot.data![index];
                          final isImage = ['.jpg', '.jpeg', '.png']
                              .contains(p.extension(file.path).toLowerCase());

                          return Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: isImage
                                  ? Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[100],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _getFileIcon(file.path),
                                            size: 40,
                                            color: Colors.blueGrey,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            p.basename(file.path),
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(note.updatedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${note.likes}')
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<List<File>> _getPreviewFiles(String noteId) async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains(noteId))
        .toList();
    return files;
  }
}
