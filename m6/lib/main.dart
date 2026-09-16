import 'package:flutter/material.dart';
import 'screens/start_screen.dart';
import 'widgets/connection_status_banner.dart';
import 'network_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // قبل از نمایش هر صفحه‌ای، آدرس درست بک‌اند رو بر اساس پلتفرم (وب/امولاتور/
  // گوشی واقعی) مشخص می‌کنیم — توضیحش تو network_config.dart هست.
  await NetworkConfig.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dating App',
      theme: ThemeData(primarySwatch: Colors.pink),
      home: const StartScreen(),
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
