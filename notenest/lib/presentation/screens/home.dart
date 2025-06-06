import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:temp/application/bloc/note/note_bloc.dart';
import 'package:temp/application/bloc/note/note_event.dart';
import 'package:temp/application/bloc/note/note_state.dart';
import 'package:temp/presentation/screens/user/user_profile.dart';
import 'package:temp/presentation/widgets/home/custom_bottom_nav_bar.dart';
import 'package:temp/presentation/widgets/home/hamburger_menu.dart';
import 'package:temp/presentation/widgets/notes/note_card.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final PageController _controller = PageController();
  final TextEditingController _searchCtrl = TextEditingController();
  int _index = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.toLowerCase().trim();
      });
    });
    context.read<NoteBloc>().add(const GetNotes(onlyPublic: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Se llama cuando se regresa a esta pantalla desde otra (como /note_detail)
    if (_index == 0) {
      context.read<NoteBloc>().add(const GetNotes(onlyPublic: true));
    }
  }

  void _handlePageChanged(int index) {
    setState(() => _index = index);
    _controller.jumpToPage(index);

    if (index == 0) {
      context.read<NoteBloc>().add(const GetNotes(onlyPublic: true));
    }
  }

  Widget _feed() => RefreshIndicator(
        onRefresh: () async =>
            context.read<NoteBloc>().add(const GetNotes(onlyPublic: true)),
        child: BlocBuilder<NoteBloc, NoteState>(
          builder: (_, state) {
            if (state is NoteLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is NotesLoaded) {
              final filtered = state.notes.where((n) {
                if (_query.isEmpty) return true;
                return n.title.toLowerCase().contains(_query) ||
                    (n.content ?? '').toLowerCase().contains(_query);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('Sin resultados'));
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (_, i) => NoteCard(
                  note: filtered[i],
                  onTap: () {
                    final note = filtered[i];
                    context.read<NoteBloc>().add(GetNoteFiles(note.id));
                    Navigator.pushNamed(
                      context,
                      '/note_detail',
                      arguments: {'note': note},
                    );
                  },
                ),
              );
            }
            return const SizedBox();
          },
        ),
      );

  Widget _searchPage() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar notas públicas…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey.shade200,
                filled: true,
              ),
            ),
          ),
          Expanded(child: _feed()),
        ],
      );

  List<Widget> get _pages => [
        _feed(),
        _searchPage(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final bool showAppBar = _index == 0;

    return Scaffold(
      drawer: showAppBar ? const HamburguerMenu() : null,
      appBar: showAppBar
          ? AppBar(
              title: const Text('NoteNest'),
              automaticallyImplyLeading: true,
            )
          : null,
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _index,
        onTap: _handlePageChanged,
      ),
    );
  }
}
