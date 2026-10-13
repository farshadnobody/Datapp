import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models/profile_models.dart';
import 'rewind_memory.dart';
import 'swipe_style.dart';

/// نتیجه‌ی «برداشتنِ لایک»: [removed] یعنی واقعاً تو بک‌اند برداشته شد؛
/// [message] (اگه null نبود) برای نمایش به کاربره.
class RemoveLikeResult {
  final bool removed;
  final String? message;
  const RemoveLikeResult(this.removed, this.message);
}

/// مشترکِ تب سواپ، اکسپلور و شیتِ جزئیات: اول تأیید می‌گیره، بعد لایک/سوپرلایک رو
/// تو بک‌اند برمی‌داره (هیچ‌وقت Unmatch نمی‌کنه) و [DiscoveryCandidate.previousDirection]
/// رو null می‌کنه تا دکمه خاموش بشه. بعد از برگشت، صفحه‌ی صداکننده باید setState بزنه.
Future<RemoveLikeResult> confirmAndRemoveLike(
    BuildContext context, DiscoveryCandidate c) async {
  final wasSuper = c.previousDirection == 'super_like';
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: kSwipeTextDirection,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          wasSuper ? 'سوپرلایک ${c.name} برداشته بشه؟' : 'لایک ${c.name} برداشته بشه؟',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          wasSuper
              ? 'بعدش می‌تونی دوباره لایک، سوپرلایک یا ردش کنی. نوتیفیکیشنی که قبلاً براش رفته پس گرفته نمی‌شه.'
              : 'بعدش می‌تونی دوباره لایک، سوپرلایک یا ردش کنی.',
          style: const TextStyle(color: Color(0xFFBDBDBD)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف', style: TextStyle(color: Color(0xFFBDBDBD))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('برداشتن', style: TextStyle(color: SwipeColors.like)),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return const RemoveLikeResult(false, null);

  try {
    // پشتِ صفِ swipeها تا به‌ترتیبِ کاربر به بک‌اند برسه.
    await RewindMemory.instance.enqueue(() => ApiClient.removeLike(c.publicId));
    RewindMemory.instance.discardLatestFor(c.publicId);
    c.previousDirection = null;
    return RemoveLikeResult(true, wasSuper ? 'سوپرلایک برداشته شد.' : 'لایک برداشته شد.');
  } on ApiException catch (e) {
    if (e.code == 'already_matched') {
      return const RemoveLikeResult(
          false, 'با این فرد متچ شدی؛ برای حذفش از پروفایلش Unmatch کن.');
    }
    return const RemoveLikeResult(false, 'برداشتنِ لایک انجام نشد.');
  } catch (_) {
    return const RemoveLikeResult(false, 'ارتباط با سرور برقرار نشد.');
  }
}
