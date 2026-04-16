import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Use AppLoader to show splash + catch init errors visibly on screen
  runApp(const AppLoader());
}

/// Shows a splash screen while Hive initialises.
/// If init fails, displays the error on screen (never a silent white screen).
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});
  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await StorageService.init();
      // Init notifications (silently — no crash if not configured)
      await NotificationService.init().catchError((_) {});
      if (mounted) {
        setState(() => _ready = true);
        // Schedule birthday reminders after first frame
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await NotificationService.scheduleBirthdayNotifications()
              .catchError((_) {});
        });
      }
    } catch (e, st) {
      if (mounted) setState(() => _error = '$e\n\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Error screen ─────────────────────────────────────────────
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  const Text('שגיאה בהפעלת האפליקציה',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'Courier',
                              color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _ready = false;
                        });
                        _init();
                      },
                      child: const Text('נסה שוב',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Splash screen ─────────────────────────────────────────────
    if (!_ready) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppTheme.primary,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contacts_rounded, color: Colors.white, size: 72),
                SizedBox(height: 20),
                Text(
                  'אנשי קשר',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 40),
                CircularProgressIndicator(
                  color: Colors.white60,
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Real app ──────────────────────────────────────────────────
    return const MyContactsApp();
  }
}

class MyContactsApp extends StatelessWidget {
  const MyContactsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: StorageService.settingsBox.listenable(),
      builder: (context, box, child) {
        final settings = StorageService.getSettings();
        return MaterialApp(
          title: 'אנשי קשר',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(seedColor: Color(settings.accentColorValue)),
          darkTheme: AppTheme.darkTheme(seedColor: Color(settings.accentColorValue)),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),
              child: child!,
            ),
          ),
          home: const MainShell(),
        );
      },
    );
  }
}
