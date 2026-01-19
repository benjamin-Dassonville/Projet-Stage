import 'package:flutter/material.dart';

import 'auth/auth_state.dart';
import 'app_state.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthState();
  await auth.init();
  authState = auth;
  runApp(App(auth: auth));
}


class App extends StatelessWidget {
  final AuthState auth;

  

  const App({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EPI Control',
      theme: ThemeData(useMaterial3: true),
      routerConfig: buildRouter(auth),
    );
  }
}