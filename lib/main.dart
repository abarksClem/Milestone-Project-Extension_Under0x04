import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:readright/config/config.dart';

// Providers
import 'package:readright/providers/studentDashboardProvider.dart';
import 'package:readright/providers/teacherProvider.dart';
import 'package:readright/providers/theme_provider.dart';

// Services
import 'package:readright/services/databaseHelper.dart';

// Authentication screens
import 'package:readright/screen/login.dart';
import 'package:readright/screen/resetPassword.dart';
import 'package:readright/screen/signup.dart';

// Student screens
import 'package:readright/screen/practice.dart';
import 'package:readright/screen/progress.dart';
import 'package:readright/screen/student/flash_dash_page.dart';
import 'package:readright/screen/studentDashboard.dart';
import 'package:readright/screen/wordList.dart';

// Teacher screens
import 'package:readright/screen/teacher/teacherDashboard.dart';
import 'package:readright/screen/teacher/teacherSettings.dart';
import 'package:readright/screen/teacher/teacherStudents.dart';
import 'package:readright/screen/teacher/teacherWordLists.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //await dotenv.load(fileName: '.env');

  MediaKit.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StudentDashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TeacherProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
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
    await _importDolchListsIfNeeded();
    await _resolveHomePage();

    if (!mounted) return;

    setState(() {
      _initialized = true;
      _checkingRole = false;
    });
  }

  Future<void> _importDolchListsIfNeeded() async {
    try {
      if (kIsWeb) return;

      final database = DatabaseHelper.instance;
      final imported = await database.isDolchImported();

      if (imported) {
        debugPrint('Dolch import skipped because words already exist.');
        return;
      }

      await database.importAllDolchLists();
      await database.setDolchImported();

      debugPrint('Dolch CSV files imported successfully.');
    } catch (error, stackTrace) {
      debugPrint('Dolch import error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _resolveHomePage() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      _homePage = const LoginPage();
      return;
    }

    _checkingRole = true;

    try {
      final result = await supabase
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      final role = result?['role'] as String? ?? 'student';

      _homePage = role == 'teacher'
          ? const TeacherDashboard()
          : const StudentDashboard();
    } catch (error, stackTrace) {
      debugPrint('Role lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      _homePage = const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isLoading = !_initialized || _checkingRole;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Color(AppConfig.primaryColor),
          secondary: Color(AppConfig.secondaryColor),
        ),
        useMaterial3: false,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
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
        // Authentication
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/resetPassword': (context) => const ResetPasswordPage(),

        // Student
        '/studentDashboard': (context) => const StudentDashboard(),
        '/practice': (context) => const PracticePage(),
        '/wordlist': (context) => const WordListPage(),
        '/progress': (context) => const ProgressPage(),
        '/flashDash': (context) => const FlashDashPage(),

        // Teacher
        '/teacherDashboard': (context) => const TeacherDashboard(),
        '/teacherWordLists': (context) => const TeacherWordListsPage(),
        '/teacherStudents': (context) => const TeacherStudentsPage(),
        '/teacherSettings': (context) => const TeacherSettingsPage(),
      },
      onUnknownRoute: (settings) {
        debugPrint('Unknown route requested: ${settings.name}');

        return MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      },
    );
  }
}