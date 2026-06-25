import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/kanban_service.dart';
import 'views/board_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await KanbanService.instance.loadTokenFromStorage();

  runApp(
    ProviderScope(
      child: TodoApp(initialRoute: token == null ? '/login' : '/board'),
    ),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginView(),
        '/register': (_) => const RegisterView(),
        '/board': (_) => const BoardView(),
      },
    );
  }
}
