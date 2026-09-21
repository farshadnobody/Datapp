import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_session.dart';
import 'screens/start_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_flow.dart';
import 'widgets/connection_status_banner.dart';
import 'network_config.dart';
import 'push_notifications.dart';
import 'swipe/swipe_onboarding_store.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // قبل از نمایش هر صفحه‌ای، آدرس درست بک‌اند رو بر اساس پلتفرم (وب/امولاتور/
  // گوشی واقعی) مشخص می‌کنیم — توضیحش تو network_config.dart هست.
  await NetworkConfig.initialize();

  // توکن ذخیره‌شده‌ی لاگین قبلی رو از روی گوشی می‌خونیم تا کاربر هر بار که
  // اپ رو باز می‌کنه مجبور به لاگین دوباره نشه.
  await AuthSession.load();

  // شمارنده‌ی «۲۰ نفر اول» (مرحله‌ی یادگیری سلیقه تو صفحه‌ی Swipe).
  await SwipeOnboarding.load();

  // اگه سرور توکن رو رد کرد (مثلاً منقضی شده)، کاربر رو برمی‌گردونیم به شروع.
  AuthSession.onExpired = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StartScreen()),
      (route) => false,
    );
  };

  // اگه هنوز google-services.json رو اضافه نکردی، این خطا می‌ده — عمداً
  // با try/catch گرفتیمش تا بدون تنظیم فایربیس هم بقیه‌ی اپ کار کنه.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotifications.initialize();
    // توکن پوش ممکنه عوض شده باشه؛ اگه کاربر از قبل لاگینه دوباره ثبتش می‌کنیم.
    if (AuthSession.isLoggedIn) {
      PushNotifications.registerToken();
    }
  } catch (e) {
    // پوش نوتیفیکیشن غیرفعال می‌مونه؛ بقیه‌ی اپ مشکلی نداره.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _initialScreen() {
    if (!AuthSession.isLoggedIn) return const StartScreen();
    return AuthSession.hasProfile
        ? const HomeScreen()
        : const OnboardingWelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dating App',
      navigatorKey: navigatorKey,
      theme: ThemeData(primarySwatch: Colors.pink),
      home: _initialScreen(),
      // این builder، کادر وضعیت اتصال رو بالای هر صفحه‌ای که تو اپ باز بشه
      // نشون می‌ده — نیازی نیست هر صفحه جدا این کار رو انجام بده.
      builder: (context, child) {
        return Column(
          children: [
            const ConnectionStatusBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
