import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/btc/offline_btc_screen.dart';
import 'screens/chats/chat_screen.dart';
import 'screens/chats/new_chat_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding/otp_verify_screen.dart';
import 'screens/onboarding/phone_entry_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'screens/settings/notifications_screen.dart';
import 'screens/settings/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';


/// Optional debug entry point so screens can be launched directly during
/// verification: `flutter run --dart-define=START=main|chat`. Defaults to the
/// normal splash flow.
const String _startAt = String.fromEnvironment('START', defaultValue: 'splash');

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  runApp(const ShadowTalkApp());
}

class ShadowTalkApp extends StatelessWidget {
  const ShadowTalkApp({super.key});

  Widget get _home {
    switch (_startAt) {
      case 'main':
        return const MainScreen();
      case 'chat':
        return const _DebugChatLauncher();
      case 'phone':
        return const PhoneEntryScreen();
      case 'otp':
        return const OtpVerifyScreen(phoneNumber: '+31 612345678');
      case 'setup':
        return const ProfileSetupScreen();
      case 'notif':
        return const NotificationsScreen();
      case 'contacts':
        return const NewChatScreen();
      case 'btc':
        return Container(
          decoration: const BoxDecoration(gradient: AppColors.bgGradient),
          child: const OfflineBtcScreen(),
        );
      case 'profile':
        return const ProfileScreen();
      default:
        return const SplashScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadow Talk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: _home,
    );
  }
}

/// Opens the main screen then immediately pushes a sample conversation — used
/// only for the `START=chat` debug entry point.
class _DebugChatLauncher extends StatefulWidget {
  const _DebugChatLauncher();

  @override
  State<_DebugChatLauncher> createState() => _DebugChatLauncherState();
}

class _DebugChatLauncherState extends State<_DebugChatLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatScreen(chatId: 'c_hugh')),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const MainScreen();
}
