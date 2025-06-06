import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:temp/domain/entities/note.dart';
import 'package:temp/domain/entities/user.dart';
import 'package:temp/presentation/screens/auth/login.dart';
import 'package:temp/presentation/screens/auth/register.dart';
import 'package:temp/presentation/screens/home.dart';
import 'package:temp/presentation/screens/notes/add_note.dart';
import 'package:temp/presentation/screens/notes/note_details.dart';
import 'package:temp/presentation/screens/splash.dart';
import 'package:temp/presentation/screens/user/public_user_profile.dart';
import 'package:temp/presentation/screens/user/user_profile.dart';
import 'package:temp/application/bloc/auth/auth_bloc.dart';
import 'package:temp/application/bloc/auth/auth_event.dart';
import 'package:temp/application/bloc/comment/comment_bloc.dart';
import 'package:temp/application/bloc/note/note_bloc.dart';
import 'package:temp/domain/repositories/auth_repository.dart';
import 'package:temp/domain/repositories/note_repository.dart';
import 'package:temp/domain/repositories/comment_repository.dart';
import 'package:temp/infrastructure/adapters/auth_repository_impl.dart';
import 'package:temp/infrastructure/adapters/note_repository_impl.dart';
import 'package:temp/infrastructure/adapters/comment_repository_impl.dart';
import 'package:temp/infrastructure/utils/shared_prefs_helper.dart';
import 'package:temp/presentation/theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  print('✅ .env cargado. API_URL: ${dotenv.env['API_URL']}');

  await SharedPrefsService().init();

  final authRepo = AuthRepositoryImpl();
  final noteRepo = NoteRepositoryImpl(authRepository: authRepo);
  final commRepo = CommentRepositoryImpl(authRepository: authRepo);

  runApp(MyApp(
    authRepository: authRepo,
    noteRepository: noteRepo,
    commentRepository: commRepo,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authRepository,
    required this.noteRepository,
    required this.commentRepository,
  });

  final AuthRepository authRepository;
  final NoteRepository noteRepository;
  final CommentRepository commentRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: noteRepository),
        RepositoryProvider.value(value: commentRepository),
      ],
      child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>(
              create: (_) => AuthBloc(authRepository)..add(LoadCurrentUser()),
            ),
            BlocProvider<NoteBloc>(
              create: (_) => NoteBloc(noteRepository),
            ),
            BlocProvider<CommentBloc>(
              create: (_) => CommentBloc(commentRepository),
            ),
          ],
          child: MaterialApp(
            navigatorObservers: [routeObserver], // ⬅️ Aquí se registra
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            title: 'NoteNest',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: '/splash',
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/splash':
                  return _page(const SplashScreen());
                case '/login':
                  return _page(const LoginScreen());
                case '/register':
                  return _page(const RegisterScreen());
                case '/home':
                  return _page(const HomeScreen());
                case '/note_detail':
                  final args = settings.arguments as Map<String, dynamic>;
                  return _page(NoteDetailScreen(note: args['note'] as Note));
                case '/create_note':
                  return _page(const AddOrEditNoteScreen());
                case '/edit_note':
                  final note = settings.arguments as Note;
                  return _page(AddOrEditNoteScreen(noteToEdit: note));
                case '/profile':
                  return _page(const ProfileScreen());
                case '/public_profile':
                  final user = settings.arguments as User;
                  return _page(PublicProfileScreen(user: user));
                default:
                  return _page(
                    const Scaffold(
                      body: Center(child: Text('Ruta no encontrada')),
                    ),
                  );
              }
            },
          )),
    );
  }

  PageRoute _page(Widget child) => MaterialPageRoute(builder: (_) => child);
}
