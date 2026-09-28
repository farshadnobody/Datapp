import 'package:flutter/foundation.dart';
import '../models/profile_models.dart';
import 'swipe_deck.dart' show SwipeDirection;

/// یه ردیفِ حافظه‌ی Rewind: کارتی که swipe شد + جهتی که روش زده شد. وضعیتِ
/// *قبل* از swipe همون candidate.previousDirection ـه (چون candidate قبل از
/// swipe از بک‌اند گرفته شده).
class RewindRecord {
  final DiscoveryCandidate candidate;
  final SwipeDirection direction;
  final DateTime at;
  RewindRecord(this.candidate, this.direction) : at = DateTime.now();
}

/// حافظه‌ی *فقط-session*ی چند swipeِ اخیر برای Rewind — بین تب‌های سواپ و
/// اکسپلور مشترکه تا ترتیبِ زمانی درست بمونه (آخرین اکشن = اولین چیزی که
/// برمی‌گرده).
///
/// عمداً هیچ‌جا ذخیره نمی‌شه (نه SharedPreferences نه فایل): با بسته شدنِ کاملِ
/// اپ یا خروج از حساب خالی می‌شه. منبعِ حقیقتِ رابطه‌ها بک‌اندِ؛ این فقط کارت‌ها
/// رو برای برگردوندن به Deck نگه می‌داره.
class RewindMemory extends ChangeNotifier {
  RewindMemory._();
  static final RewindMemory instance = RewindMemory._();

  static const int maxRecords = 10;
  final List<RewindRecord> _records = [];

  bool get canRewind => _records.isNotEmpty;
  RewindRecord? get latest => _records.isEmpty ? null : _records.last;

  void push(DiscoveryCandidate candidate, SwipeDirection direction) {
    _records.add(RewindRecord(candidate, direction));
    if (_records.length > maxRecords) _records.removeAt(0);
    notifyListeners();
  }

  /// swipe/rewindها باید *به همون ترتیبی که کاربر زده* به بک‌اند برسن؛ وگرنه
  /// Rewind ممکنه قبل از رسیدنِ swipeِ خودش اجرا بشه. این صف همه‌ی این
  /// درخواست‌ها رو پشتِ هم اجرا می‌کنه (خطای یکی، بقیه رو متوقف نمی‌کنه).
  Future<void> _tail = Future.value();
  Future<T> enqueue<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// یه رکوردِ مشخص رو (با identity) برمی‌داره.
  void remove(RewindRecord record) {
    if (_records.remove(record)) notifyListeners();
  }

  /// آخرین رکورد رو برمی‌داره (بعد از موفقیتِ Rewind تو بک‌اند).
  RewindRecord? popLatest() {
    if (_records.isEmpty) return null;
    final r = _records.removeLast();
    notifyListeners();
    return r;
  }

  /// وقتی یه swipe منجر به متچ شد، دیگه قابل‌برگشت نیست (بک‌اند هم ردش
  /// می‌کنه)؛ از استک درش می‌آریم تا Rewind بعدی به آخرین اکشنِ *قابل‌برگشت*
  /// برسه.
  void discardLatestFor(String publicId) {
    for (var i = _records.length - 1; i >= 0; i--) {
      if (_records[i].candidate.publicId == publicId) {
        _records.removeAt(i);
        notifyListeners();
        return;
      }
    }
  }

  void clear() {
    if (_records.isEmpty) return;
    _records.clear();
    notifyListeners();
  }
}

/// آیا ثبتِ [direction] روی کسی که وضعیتِ قبلیش [previous] بود چیزی رو تو بک‌اند
/// عوض می‌کنه؟ (باید با swipeChangesState تو بک‌اند یکی باشه.) اگه نه، کارت فقط
/// رد می‌شه و چیزی برای Rewind ثبت نمی‌شه.
bool swipeChangesState(String? previous, String direction) {
  if (previous == null) return true;
  if (previous == direction) return false;
  final wasInterested = previous == 'like' || previous == 'super_like';
  if (direction == 'pass' && wasInterested) return false;
  if (direction == 'like' && previous == 'super_like') return false;
  return true;
}
