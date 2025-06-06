import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/application/bloc/comment/comment_bloc.dart';
import 'package:temp/application/bloc/comment/comment_event.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/infrastructure/utils/shared_prefs_helper.dart';

class NoteLikeButton extends StatefulWidget {
  final Note note;

  const NoteLikeButton({super.key, required this.note});

  @override
  State<NoteLikeButton> createState() => _NoteLikeButtonState();
}

class _NoteLikeButtonState extends State<NoteLikeButton> {
  late bool _liked;
  late int _likes;
  final String _prefsKey = 'liked_';

  @override
  void initState() {
    super.initState();
    _likes = widget.note.likes;
    _liked = SharedPrefsService.instance.getBool(_prefsKey + widget.note.id) ??
        false;
  }

  Future<void> _toggleLike() async {
    final isLiked = _liked;
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });

    final bloc = context.read<CommentBloc>();
    if (!isLiked) {
      await SharedPrefsService.instance
          .setBool(_prefsKey + widget.note.id, true);
      bloc.add(LikeNote(widget.note.id));
    } else {
      await SharedPrefsService.instance
          .setBool(_prefsKey + widget.note.id, false);
      bloc.add(UnlikeNote(widget.note.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_liked ? Icons.favorite : Icons.favorite_border,
              color: _liked ? Colors.red : Colors.grey),
          onPressed: _toggleLike,
        ),
        Text('$_likes')
      ],
    );
  }
}
