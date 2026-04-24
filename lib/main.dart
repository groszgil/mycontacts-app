import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
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
          await NotificationService.scheduleAnniversaryNotifications()
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
          home: const _LockRoot(),
        );
      },
    );
  }
}

// ── Biometric lock root ────────────────────────────────────────────────────

class _LockRoot extends StatefulWidget {
  const _LockRoot();

  @override
  State<_LockRoot> createState() => _LockRootState();
}

class _LockRootState extends State<_LockRoot> with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  bool _wasInBackground = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (StorageService.isAppLockEnabled) {
      _locked = true;
      // Delay until first frame so the UI is visible before the auth dialog
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed &&
        _wasInBackground &&
        StorageService.isAppLockEnabled) {
      _wasInBackground = false;
      setState(() => _locked = true);
      _authenticate();
    } else if (state == AppLifecycleState.resumed) {
      _wasInBackground = false;
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    try {
      final canCheck = await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
      if (!canCheck) {
        // Device has no biometrics — unlock automatically
        if (mounted) setState(() { _locked = false; _authenticating = false; });
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'אמת זהות כדי לפתוח את אנשי הקשר',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (mounted) {
        setState(() { _locked = !ok; _authenticating = false; });
      }
    } catch (_) {
      // If auth fails / not available → unlock gracefully
      if (mounted) setState(() { _locked = false; _authenticating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return const MainShell();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 52),
              ),
              const SizedBox(height: 28),
              const Text(
                'אנשי קשר',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'האפליקציה נעולה',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _authenticating ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _authenticating
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fingerprint_rounded, size: 24),
                label: Text(
                  _authenticating ? 'מאמת...' : 'פתח עם ביומטריה',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
