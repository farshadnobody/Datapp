import 'package:flutter/foundation.dart';

/// وضعیتِ اتصال به سرور، بدون هیچ درخواستِ اضافه: هر درخواستی که جواب بگیره
/// «وصل» و هر درخواستی که به‌خاطر شبکه شکست بخوره «قطع» رو گزارش می‌کنه.
/// null = هنوز هیچ درخواستی نزدیم.
class ConnectionMonitor {
  ConnectionMonitor._();

  static final ValueNotifier<bool?> online = ValueNotifier<bool?>(null);

  static void reportSuccess() {
    if (online.value != true) online.value = true;
  }

  static void reportFailure() {
    if (online.value != false) online.value = false;
  }
}
