import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';

// عمداً import مستقیم onboarding_flow.dart نکردیم (می‌شد چرخه‌ی import با
// home_screen.dart → profile_home_screen.dart → این فایل)؛ همون مقدارهای
// kOnboardingMaxBio / kOnboardingMaxPromptAnswer اونجا رو این‌جا هم عیناً
// نگه داشتیم.
const int _maxBio = 500;
const int _maxPromptAnswer = 150;

/// نسخه‌ی «عمومی» صفحه‌های ویرایش بیو و پرامپت — دقیقاً همون ظاهر
/// _AddBioScreen / _SelectPromptScreen / _AnswerPromptScreen تو
/// onboarding_flow.dart، ولی چون اون‌ها private بودن (پیش‌وند _) نمی‌شد
/// از بیرون اون فایل صداشون زد. صفحه‌ی «پروفایل من» (بخش My Prompts) از
/// همین نسخه استفاده می‌کنه.
class BioEditScreen extends StatefulWidget {
  final String initialBio;
  const BioEditScreen({super.key, required this.initialBio});

  @override
  State<BioEditScreen> createState() => _BioEditScreenState();
}

class _BioEditScreenState extends State<BioEditScreen> {
  late final _controller = TextEditingController(text: widget.initialBio);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppDark.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: AppDark.bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: const Text('درباره‌ی من',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: canSubmit ? Colors.white : const Color(0xFF2C2C2E),
                    foregroundColor: canSubmit ? Colors.black : const Color(0xFF636366),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop(_controller.text.trim())
                      : null,
                  child: const Text('تمام', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 6,
              maxLength: _maxBio,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'مثلاً: عاشق کوه و قهوه‌ام، دنبال یکی که...',
                hintStyle: TextStyle(color: AppDark.muted),
                counterStyle: TextStyle(color: AppDark.muted),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
    );
  }
}

/// صفحه‌ی «یه پرامپت انتخاب کن» — لیست پرامپت‌های آماده.
class PromptSelectScreen extends StatelessWidget {
  final List<OptionItem> prompts;
  const PromptSelectScreen({super.key, required this.prompts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDark.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: AppDark.bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: const Text('یه پرامپت انتخاب کن',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: prompts.length,
          separatorBuilder: (_, __) => const Divider(color: AppDark.border, height: 1),
          itemBuilder: (context, i) {
            final p = prompts[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.label, style: const TextStyle(color: Colors.white, fontSize: 15)),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(p);
              },
            );
          },
        ),
      ),
    );
  }
}

/// صفحه‌ی «جواب به پرامپت». خروجی: {'prompt_id':..., 'label':..., 'answer':...}
class PromptAnswerScreen extends StatefulWidget {
  final String promptId;
  final String promptLabel;
  final String initialAnswer;
  final List<OptionItem> prompts;

  const PromptAnswerScreen({
    super.key,
    required this.promptId,
    required this.promptLabel,
    required this.initialAnswer,
    required this.prompts,
  });

  @override
  State<PromptAnswerScreen> createState() => _PromptAnswerScreenState();
}

class _PromptAnswerScreenState extends State<PromptAnswerScreen> {
  late final _controller = TextEditingController(text: widget.initialAnswer);
  late String _promptId = widget.promptId;
  late String _promptLabel = widget.promptLabel;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changePrompt() async {
    final chosen = await Navigator.of(context).push<OptionItem>(
      MaterialPageRoute(builder: (_) => PromptSelectScreen(prompts: widget.prompts)),
    );
    if (chosen != null && mounted) {
      setState(() {
        _promptId = chosen.id;
        _promptLabel = chosen.label;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppDark.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: AppDark.bg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: const Text('جواب به پرامپت',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: canSubmit ? Colors.white : const Color(0xFF2C2C2E),
                    foregroundColor: canSubmit ? Colors.black : const Color(0xFF636366),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop({
                            'prompt_id': _promptId,
                            'label': _promptLabel,
                            'answer': _controller.text.trim(),
                          })
                      : null,
                  child: const Text('تمام', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _changePrompt,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_promptLabel,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.chevron_left, color: AppDark.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: _maxPromptAnswer,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'یه‌چیز باحال بنویس...',
                    hintStyle: TextStyle(color: AppDark.muted),
                    counterStyle: TextStyle(color: AppDark.muted),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
