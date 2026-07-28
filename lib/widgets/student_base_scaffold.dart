import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:readright/config/config.dart';
import 'package:readright/providers/theme_provider.dart';
import 'package:readright/widgets/student_navbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentBaseScaffold extends StatelessWidget {
  final Widget body;
  final String pageTitle;
  final IconData pageIcon;
  final int currentIndex;
  final bool showBottomNavigationBar;
  final Future<bool> Function()? onBeforeLogout;

  const StudentBaseScaffold({
    super.key,
    required this.body,
    required this.pageTitle,
    required this.pageIcon,
    required this.currentIndex,
    this.showBottomNavigationBar = true,
    this.onBeforeLogout,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(AppConfig.primaryColor),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Icon(pageIcon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              pageTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: themeProvider.isDarkMode
                ? const Icon(Icons.light_mode, color: Colors.white)
                : const Icon(Icons.dark_mode, color: Colors.white),
            tooltip: 'Dark mode',
            onPressed: themeProvider.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              final mayLogout = onBeforeLogout == null
                  ? true
                  : await onBeforeLogout!();
              if (!mayLogout || !context.mounted) return;

              final supabase = Supabase.instance.client;
              await supabase.auth.signOut();

              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: showBottomNavigationBar
          ? StudentNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(
                context,
                '/studentDashboard',
              );
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/practice');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/wordlist');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/progress');
              break;
            default:
              Navigator.pushReplacementNamed(
                context,
                '/studentDashboard',
              );
          }
        },
      )
          : null,
    );
  }
}
