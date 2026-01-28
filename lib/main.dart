import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'data/chat_repository.dart';
import 'firebase_options.dart';
import 'login_info.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(App());
}

class App extends StatefulWidget {
  App({super.key}) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      LoginInfo.instance.user = user;
      ChatRepository.user = user;
    });
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _router = GoRouter(
    routes: [
      GoRoute(name: 'home', path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        name: 'login',
        path: '/login',
        builder: (context, state) => Stack(
          children: [
            // ✅ 배경 이미지
            Positioned.fill(
              child: Image.asset(
                'assets/images/hanji.png',
                fit: BoxFit.cover, // 꽉 채우기 (텍스처가 큰 이미지라면 추천)
              ),
            ),

            // ✅ SignInScreen의 Scaffold 배경을 투명하게 만들어
            //    뒤의 이미지가 보이도록 함
            Theme(
              data: Theme.of(context).copyWith(scaffoldBackgroundColor: Colors.transparent),
              child: SignInScreen(
                showAuthActionSwitch: true,
                breakpoint: 600,
                providers: LoginInfo.authProviders,
                showPasswordVisibilityToggle: true,
              ),
            ),
          ],
        ),
      ),
    ],
    redirect: (context, state) {
      final loginLocation = state.namedLocation('login');
      final homeLocation = state.namedLocation('home');
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final loggingIn = state.matchedLocation == loginLocation;

      if (!loggedIn && !loggingIn) return loginLocation;
      if (loggedIn && loggingIn) return homeLocation;

      return null;
    },
    refreshListenable: LoginInfo.instance,
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: _router,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    // 다크 테마도 만들면:
    // darkTheme: AppTheme.dark(),
    // themeMode: ThemeMode.system,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: const [
      FirebaseUILocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}
