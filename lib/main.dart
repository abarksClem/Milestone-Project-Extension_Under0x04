import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:readright/providers/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/config.dart';
import 'package:readright/services/databaseHelper.dart';

// Providers
import 'package:readright/providers/studentDashboardProvider.dart';
import 'package:readright/providers/teacherProvider.dart';

// Screens
import 'package:readright/screen/login.dart';
import 'package:readright/screen/signup.dart';
import 'package:readright/screen/resetPassword.dart';
import 'package:readright/screen/studentDashboard.dart';
import 'package:readright/screen/progress.dart';
import 'package:readright/screen/practice.dart';
import 'package:readright/screen/wordList.dart';
import 'package:readright/screen/feedback.dart';
import 'package:readright/screen/teacher/teacherDashboard.dart';
import 'package:readright/screen/teacher/teacherWordLists.dart';
import 'package:readright/screen/teacher/teacherStudents.dart';
import 'package:readright/screen/teacher/teacherSettings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  const supabaseUrl = AppConfig.supabaseUrl;
  const supabaseAnonKey = AppConfig.supabaseAnonKey;

  MediaKit.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudentDashboardProvider()),
        ChangeNotifierProvider(create: (_) => TeacherProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider())
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  bool _checkingRole = false;
  Widget? _homePage;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      if (!kIsWeb) {
        final db = DatabaseHelper.instance;
        final imported = await db.isDolchImported();

        if (!imported) {
          await db.importAllDolchLists();
          await db.setDolchImported();
          debugPrint("Dolch CSV imported (first run)");
        } else {
          debugPrint("Dolch import skipped (already imported)");
        }
      }
    } catch (e) {
      debugPrint("Dolch import error: $e");
    }

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      _homePage = const LoginPage();
    } else {
      _checkingRole = true;
      try {
        final userId = session.user.id;
        final result = await supabase
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle();

        final role = result?['role'] ?? 'student';
        _homePage =
        (role == 'teacher') ? const TeacherDashboard() : const StudentDashboard();
      } catch (e) {
        debugPrint("Role lookup failed: $e");
        _homePage = const LoginPage();
      }
    }

    if (mounted) {
      setState(() {
        _initialized = true;
        _checkingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final bool isLoading = !_initialized || _checkingRole;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,

      initialRoute: '/',

      theme: ThemeData(
        colorScheme: themeProvider.isDarkMode
            ? ColorScheme.dark(
          primary: Color(AppConfig.primaryColor),
          secondary: Color(AppConfig.secondaryColor),
        )
            : ColorScheme.light(
          primary: Color(AppConfig.primaryColor),
          secondary: Color(AppConfig.secondaryColor),
        ),
        useMaterial3: false,
      ),

      home: isLoading
          ? const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      )
          : (_homePage ?? const LoginPage()),

      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/resetPassword': (context) => const ResetPasswordPage(),

        '/studentDashboard': (context) => const StudentDashboard(),
        '/progress': (context) => const ProgressPage(),
        '/practice': (context) => const PracticePage(),
        '/wordlist': (context) => const WordListPage(),
        '/feedback': (context) => const FeedbackPage(),

        '/teacherDashboard': (context) => const TeacherDashboard(),
        '/teacherWordLists': (context) =>
        const TeacherWordListsPage(),
        '/teacherStudents': (context) =>
        const TeacherStudentsPage(),
        '/teacherSettings': (context) =>
        const TeacherSettingsPage(),
      },

      onUnknownRoute: (settings) {
        debugPrint('Unknown route requested: ${settings.name}');

        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      },
    );
  }
}
