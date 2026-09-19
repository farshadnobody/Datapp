import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../auth_session.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import 'auth_ui.dart'; // AuthColors, kAppName
import 'home_screen.dart';

/// حداکثر طول بیو و جواب پرامپت — تو صفحه‌های «اضافه کردن بیو» و «جواب به
/// پرامپت» استفاده می‌شن.
const int kOnboardingMaxBio = 500;
const int kOnboardingMaxPromptAnswer = 150;

/// رنگ‌های اختصاصیِ این فلو (تم تیره، نزدیک به حس‌وحال تیندر ولی عیناً
/// همون کد رنگی نیست — کارت‌ها تقریباً مشکی، حاشیه‌ها خاکستری تیره، متن
/// کم‌رنگ‌ها خاکستری روشن‌تر، و قرمز برند خودمون برای نوار پیشرفت).
class _OB {
  static const bg = Colors.black;
  static const card = Color(0xFF121214);
  static const border = Color(0xFF35353A);
  static const muted = Color(0xFFA6A6AA);
  static const accent = AuthColors.red;
}

/// صفحه‌ی «قوانین خونه» — اولین صفحه‌ای که کاربر بعد از ثبت‌نام می‌بینه.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _OB.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(Icons.favorite, color: _OB.accent, size: 40),
                const SizedBox(height: 20),
                const Text(
                  'به $kAppName خوش اومدی.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'لطفاً این قوانین رو رعایت کن.',
                  style: TextStyle(color: _OB.muted, fontSize: 15),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: ListView(
                    children: const [
                      _RuleItem(
                        title: 'خودت باش.',
                        body:
                            'مطمئن شو عکس‌ها، سنّ و بیوت واقعاً همون چیزیه که هستی.',
                      ),
                      _RuleItem(
                        title: 'مراقب خودت باش.',
                        body:
                            'اطلاعات شخصیت رو زود به کسی نده. با احتیاط قرار حضوری بذار.',
                      ),
                      _RuleItem(
                        title: 'محترمانه رفتار کن.',
                        body:
                            'به بقیه همون‌طوری رفتار کن که دوست داری باهات رفتار بشه.',
                      ),
                      _RuleItem(
                        title: 'فعال باش.',
                        body: 'رفتار نامناسب رو همیشه گزارش بده.',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const OnboardingFlowScreen(),
                      ));
                    },
                    child: const Text('قبول دارم',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String title;
  final String body;
  const _RuleItem({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  color: _OB.muted, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

/// خودِ فلوی چندمرحله‌ای: هر سؤال یه صفحه، با نوار پیشرفت بالا، دکمه‌ی
/// برگشت، و دکمه‌ی «رد کردن» فقط برای مراحل اختیاری.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

enum _Step {
  name,
  birthday,
  gender,
  orientation,
  seeing,
  lookingFor,
  education,
  school,
  lifestyle,
  aboutYou,
  interests,
  photos,
  bioAndPrompts,
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final _pageController = PageController();
  int _index = 0;
  final _steps = _Step.values;

  ProfileOptions? _serverOptions; // برای گرفتن لیست prompts از بک‌اند
  bool _loadingOptions = true;

  // --- state جواب‌ها ---
  final _nameController = TextEditingController();
  final _birthDateInputController = TextEditingController();
  DateTime? _birthDate;
  final Set<String> _genders = {};
  bool _showGenderOnProfile = true;
  final Set<String> _orientations = {};
  bool _showOrientationOnProfile = false;
  final Set<String> _seeing = {};
  String? _lookingFor;
  String? _education;
  final _schoolController = TextEditingController();
  final Map<String, String> _lifestyle = {};
  final Map<String, String> _aboutYou = {};
  final Set<String> _interests = {};
  final Set<String> _expandedInterestCats = {};
  final List<XFile> _photos = [];
  final _bioController = TextEditingController();
  String? _selectedPromptId;
  String? _selectedPromptText;
  final _promptAnswerController = TextEditingController();

  static const int _maxInterests = 10;
  static const int _maxPhotos = 6;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await ApiClient.fetchProfileOptions();
      setState(() {
        _serverOptions = options;
        _loadingOptions = false;
      });
    } catch (_) {
      // اگه بک‌اند هنوز این فیلدهای جدید رو نداشت، با پرامپت‌های محلی ادامه بده.
      setState(() => _loadingOptions = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _birthDateInputController.dispose();
    _schoolController.dispose();
    _bioController.dispose();
    _promptAnswerController.dispose();
    super.dispose();
  }

  int get _age {
    final birthDate = _birthDate;
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final hadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// از رشته‌ی خام اعدادی که کاربر با کیبرد تایپ کرده (بدون خط تیره) یه
  /// تاریخ معتبر می‌سازه، یا اگه هنوز کامل/معتبر نیست null برمی‌گردونه.
  DateTime? _parseBirthDigits(String digits) {
    if (digits.length != 8) return null;
    final month = int.tryParse(digits.substring(0, 2));
    final day = int.tryParse(digits.substring(2, 4));
    final year = int.tryParse(digits.substring(4, 8));
    if (month == null || day == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 1900 || year > DateTime.now().year) return null;
    final d = DateTime(year, month, day);
    if (d.month != month || d.day != day) return null; // روزهای نامعتبر مثل ۳۱ فوریه
    return d;
  }

  bool get _hasBio => _bioController.text.trim().isNotEmpty;
  bool get _hasPromptAnswer =>
      _selectedPromptId != null && _promptAnswerController.text.trim().isNotEmpty;

  bool get _currentValid {
    switch (_steps[_index]) {
      case _Step.name:
        return _nameController.text.trim().isNotEmpty;
      case _Step.birthday:
        return _birthDate != null && _age >= 18;
      case _Step.gender:
        return _genders.isNotEmpty;
      case _Step.orientation:
        return _orientations.isNotEmpty;
      case _Step.seeing:
        return _seeing.isNotEmpty;
      case _Step.lookingFor:
        return _lookingFor != null;
      case _Step.education:
        return _education != null;
      case _Step.school:
        return _schoolController.text.trim().isNotEmpty;
      case _Step.lifestyle:
        return _lifestyle.isNotEmpty;
      case _Step.aboutYou:
        return _aboutYou.isNotEmpty;
      case _Step.interests:
        return _interests.isNotEmpty;
      case _Step.photos:
        return _photos.isNotEmpty;
      case _Step.bioAndPrompts:
        return _hasBio || _hasPromptAnswer;
    }
  }

  String _nextLabel(_Step step) {
    switch (step) {
      case _Step.lifestyle:
        return 'بعدی ${_lifestyle.length}/${kLifestyleCategories.length}';
      case _Step.aboutYou:
        return 'بعدی ${_aboutYou.length}/${kAboutYouCategories.length}';
      case _Step.interests:
        return 'بعدی ${_interests.length}/$_maxInterests';
      default:
        return 'بعدی';
    }
  }

  void _goNext() async {
    if (!_currentValid) return;
    HapticFeedback.lightImpact();
    if (_steps[_index] == _Step.name) {
      final confirmed = await _showNameConfirmSheet();
      if (confirmed != true) return;
    }
    if (_index == _steps.length - 1) {
      await _goToLocationScreen();
      return;
    }
    setState(() => _index++);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goBack() {
    if (_index == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _index--);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _skip() {
    HapticFeedback.lightImpact();
    if (_index == _steps.length - 1) {
      _goToLocationScreen();
      return;
    }
    setState(() => _index++);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _goToLocationScreen() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _LocationPermissionScreen(onAllow: _submitEverything),
    ));
  }

  Future<bool?> _showNameConfirmSheet() {
    final name = _nameController.text.trim();
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: _OB.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('خوش اومدی، $name!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text(
                'کلی آدم جدید منتظرته. اول بیا پروفایلت رو کامل کنیم.',
                style: TextStyle(color: _OB.muted, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('بزن بریم'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ویرایش اسم',
                    style: TextStyle(color: _OB.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// همه‌ی جواب‌های جمع‌شده رو می‌فرسته، عکس‌ها رو آپلود می‌کنه، موقعیت مکانی
  /// رو (در صورت اجازه) ثبت می‌کنه، و به HomeScreen می‌ره. خطاها رو عمداً
  /// catch نمی‌کنه — صفحه‌ی موقعیت مکانی (که این متد رو صدا می‌زنه) خودش
  /// try/catch داره و پیام خطا رو نشون می‌ده.
  Future<void> _submitEverything() async {
    final prompts = <PromptAnswer>[];
    if (_hasPromptAnswer) {
      prompts.add(PromptAnswer(
        promptId: _selectedPromptId!,
        answer: _promptAnswerController.text.trim(),
      ));
    }

    final input = ProfileInput(
      name: _nameController.text.trim(),
      birthDate:
          '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
      // اگه بک‌اند هنوز چندانتخابی نداره، اولین مقدار رو به‌عنوان فیلد
      // اصلی gender/interestedIn می‌فرستیم تا با API فعلی سازگار بمونه.
      gender: _genders.isNotEmpty ? _genders.first : '',
      interestedIn: _seeing.isNotEmpty ? _seeing.first : '',
      bio: _bioController.text.trim(),
      interests: _interests.toList(),
      prompts: prompts,
      genders: _genders.toList(),
      showGenderOnProfile: _showGenderOnProfile,
      sexualOrientations: _orientations.toList(),
      showOrientationOnProfile: _showOrientationOnProfile,
      interestedInMulti: _seeing.toList(),
      lookingFor: _lookingFor,
      educationLevel: _education,
      school: _schoolController.text.trim(),
      lifestyle: _lifestyle,
      aboutYou: _aboutYou,
    );
    await ApiClient.saveProfile(input);

    for (final photo in _photos) {
      final bytes = await photo.readAsBytes();
      await ApiClient.uploadPhoto(bytes, photo.name);
    }

    await _requestLocationSilently();

    await AuthSession.setHasProfile(true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _requestLocationSilently() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await ApiClient.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // موقعیت اختیاریه؛ اگه نشد، ثبت‌نام رو متوقف نکن.
    }
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loadingOptions) {
      return const Scaffold(
        backgroundColor: _OB.bg,
        body: Center(child: CircularProgressIndicator(color: _OB.accent)),
      );
    }

    final step = _steps[_index];
    final progress = (_index + 1) / _steps.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBack();
        },
        child: Scaffold(
          backgroundColor: _OB.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(step, progress),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _steps.map(_buildStepBody).toList(),
                  ),
                ),
                _buildBottomBar(step),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSkippable(_Step step) {
    switch (step) {
      case _Step.name:
      case _Step.birthday:
      case _Step.gender:
      case _Step.seeing:
      case _Step.photos:
        return false;
      default:
        return true;
    }
  }

  Widget _buildHeader(_Step step, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goBack,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: _OB.border,
                valueColor: const AlwaysStoppedAnimation(_OB.accent),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: _isSkippable(step)
                ? TextButton(
                    onPressed: _skip,
                    child: const Text('رد کردن',
                        style: TextStyle(color: _OB.muted)),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(_Step step) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentValid ? Colors.white : _OB.border,
            foregroundColor: _currentValid ? Colors.black : _OB.muted,
            disabledBackgroundColor: _OB.border,
            disabledForegroundColor: _OB.muted,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          onPressed: _currentValid ? _goNext : null,
          child: Text(_nextLabel(step),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildStepBody(_Step step) {
    switch (step) {
      case _Step.name:
        return _stepName();
      case _Step.birthday:
        return _stepBirthday();
      case _Step.gender:
        return _stepGender();
      case _Step.orientation:
        return _stepOrientation();
      case _Step.seeing:
        return _stepSeeing();
      case _Step.lookingFor:
        return _stepLookingFor();
      case _Step.education:
        return _stepEducation();
      case _Step.school:
        return _stepSchool();
      case _Step.lifestyle:
        return _stepCategorized(
          title: 'بیا از عادت‌های زندگیت بگیم',
          subtitle: 'عادت‌هاتون بهم می‌خوره؟ اول تو بگو.',
          categories: kLifestyleCategories,
          selections: _lifestyle,
        );
      case _Step.aboutYou:
        return _stepCategorized(
          title: 'چی تو رو، تو می‌کنه؟',
          subtitle: 'رو نگیر. اصالت جذابیت میاره.',
          categories: kAboutYouCategories,
          selections: _aboutYou,
        );
      case _Step.interests:
        return _stepInterests();
      case _Step.photos:
        return _stepPhotos();
      case _Step.bioAndPrompts:
        return _stepBioAndPrompts();
    }
  }

  // ------------------------- ویجت‌های عمومی -------------------------

  Widget _scrollableStep({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle,
                style: const TextStyle(
                    color: _OB.muted, fontSize: 14, height: 1.5)),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _selectableBox({
    required String label,
    String? description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? Colors.white : _OB.border, width: 1.4),
            color: selected ? Colors.white10 : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        color: _OB.muted, fontSize: 12.5, height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.white : _OB.border, width: 1.2),
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _checkboxRow(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: _OB.accent,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: _OB.muted, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  /// ردیف «نمایش بیشتر / نمایش کمتر» زیر هر دسته‌ی علاقه‌مندی — دو خط نازک
  /// کنار یه متن با فلش، دقیقاً مثل تیندر.
  Widget _showMoreToggle(String categoryId, bool expanded) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => setState(() {
          if (expanded) {
            _expandedInterestCats.remove(categoryId);
          } else {
            _expandedInterestCats.add(categoryId);
          }
        }),
        child: Row(
          children: [
            const Expanded(child: Divider(color: _OB.border, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(expanded ? 'نمایش کمتر' : 'نمایش بیشتر',
                      style: const TextStyle(color: _OB.muted, fontSize: 13)),
                  Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _OB.muted,
                      size: 18),
                ],
              ),
            ),
            const Expanded(child: Divider(color: _OB.border, height: 1)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required String title,
    required String subtitle,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _OB.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _OB.muted, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: Icon(filled ? Icons.check : Icons.add,
                  size: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------- مراحل -------------------------

  Widget _stepName() {
    return _scrollableStep(
      title: 'اسمت چیه؟',
      subtitle: 'همینی که وارد می‌کنی تو پروفایلت نشون داده می‌شه. بعداً '
          'نمی‌تونی عوضش کنی.',
      child: TextField(
        controller: _nameController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        maxLength: 40,
        decoration: const InputDecoration(
          hintText: 'اسم کوچیکت رو بنویس',
          hintStyle: TextStyle(color: _OB.muted),
          counterStyle: TextStyle(color: _OB.muted),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.border)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.accent, width: 2)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _stepBirthday() {
    return _scrollableStep(
      title: 'تولدت کِیه؟',
      subtitle: 'تو پروفایلت فقط سنّت نشون داده می‌شه، نه تاریخ تولدت.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // فرمت تاریخ (ماه/روز/سال) همیشه چپ‌به‌راست تایپ می‌شه، حتی تو
          // اپ راست‌چین — دقیقاً مثل تیندر.
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _birthDateInputController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [_DateInputFormatter()],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1),
              decoration: const InputDecoration(
                hintText: 'M M / D D / Y Y Y Y',
                hintStyle: TextStyle(color: _OB.muted, letterSpacing: 4),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                setState(() => _birthDate = _parseBirthDigits(digits));
              },
            ),
          ),
          if (_birthDate != null && _age < 18) ...[
            const SizedBox(height: 12),
            const Text('باید حداقل ۱۸ سالت باشه.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _stepGender() {
    return _scrollableStep(
      title: 'جنسیتت چیه؟',
      subtitle:
          'هرچی که با هویتت جور در میاد رو انتخاب کن. می‌تونی چندتا بزنی.',
      child: Column(
        children: [
          ...kGenderOptions.map((o) => _selectableBox(
                label: o.label,
                selected: _genders.contains(o.id),
                onTap: () => setState(() {
                  _genders.contains(o.id)
                      ? _genders.remove(o.id)
                      : _genders.add(o.id);
                }),
              )),
          const SizedBox(height: 8),
          _checkboxRow('جنسیتم تو پروفایل نشون داده بشه', _showGenderOnProfile,
              (v) => setState(() => _showGenderOnProfile = v)),
        ],
      ),
    );
  }

  Widget _stepOrientation() {
    return _scrollableStep(
      title: 'گرایش جنسیت چیه؟',
      subtitle: 'هرچی که هویتت رو نشون می‌ده انتخاب کن.',
      child: Column(
        children: [
          ...kOrientationOptions.map((o) => _selectableBox(
                label: o.label,
                description: o.description,
                selected: _orientations.contains(o.id),
                onTap: () => setState(() {
                  _orientations.contains(o.id)
                      ? _orientations.remove(o.id)
                      : _orientations.add(o.id);
                }),
              )),
          const SizedBox(height: 8),
          _checkboxRow('گرایش جنسیم تو پروفایل نشون داده بشه',
              _showOrientationOnProfile,
              (v) => setState(() => _showOrientationOnProfile = v)),
        ],
      ),
    );
  }

  Widget _stepSeeing() {
    return _scrollableStep(
      title: 'به دنبال دیدن چه کسایی هستی؟',
      subtitle:
          'هرچی که مدنظرته رو انتخاب کن تا بهترین پیشنهادها رو بهت بدیم.',
      child: Column(
        children: kSeeingOptions
            .map((o) => _selectableBox(
                  label: o.label,
                  selected: _seeing.contains(o.id),
                  onTap: () => setState(() {
                    _seeing.contains(o.id)
                        ? _seeing.remove(o.id)
                        : _seeing.add(o.id);
                  }),
                ))
            .toList(),
      ),
    );
  }

  Widget _stepLookingFor() {
    return _scrollableStep(
      title: 'دنبال چه نوع رابطه‌ای هستی؟',
      subtitle: 'مشکلی نیست اگه بعداً عوض شد. یه چیزی برای همه هست.',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: kLookingForOptions.map((o) {
          final selected = _lookingFor == o.id;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _lookingFor = o.id);
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? Colors.white : _OB.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? Colors.white : _OB.border, width: 1.4),
              ),
              child: Text(o.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepEducation() {
    return _scrollableStep(
      title: 'میزان تحصیلاتت چیه؟',
      subtitle: 'این به بهتر شدن پیشنهادهات کمک می‌کنه.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kEducationOptions
            .map((o) => _pillChip(
                  label: o.label,
                  selected: _education == o.id,
                  onTap: () => setState(() => _education = o.id),
                ))
            .toList(),
      ),
    );
  }

  Widget _stepSchool() {
    return _scrollableStep(
      title: 'کجا درس خوندی؟',
      subtitle: 'یه حس اشتراک، راه ارتباط رو بازتر می‌کنه.',
      child: TextField(
        controller: _schoolController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        decoration: const InputDecoration(
          hintText: 'اسم مدرسه یا دانشگاه',
          hintStyle: TextStyle(color: _OB.muted),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.border)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _OB.accent, width: 2)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _stepCategorized({
    required String title,
    required String subtitle,
    required List<OptionCategory> categories,
    required Map<String, String> selections,
  }) {
    return _scrollableStep(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cat.items
                      .map((item) => _pillChip(
                            label: item.label,
                            selected: selections[cat.id] == item.id,
                            onTap: () => setState(() {
                              if (selections[cat.id] == item.id) {
                                selections.remove(cat.id);
                              } else {
                                selections[cat.id] = item.id;
                              }
                            }),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepInterests() {
    return _scrollableStep(
      title: 'به چی علاقه داری؟',
      subtitle:
          'تا ۱۰ تا انتخاب کن تا با آدم‌هایی که سلیقه‌ی مشترک دارن راحت‌تر '
          'وصل بشی.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: kInterestCategories.map((cat) {
          final expanded = _expandedInterestCats.contains(cat.id);
          final visibleItems =
              expanded ? cat.items : cat.items.take(kInterestPreviewCount);
          return Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: visibleItems.map((item) {
                    final selected = _interests.contains(item.id);
                    return _pillChip(
                      label: item.label,
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _interests.remove(item.id);
                        } else if (_interests.length < _maxInterests) {
                          _interests.add(item.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
                if (cat.items.length > kInterestPreviewCount)
                  _showMoreToggle(cat.id, expanded),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepPhotos() {
    return _scrollableStep(
      title: 'چندتا عکس اخیرت رو اضافه کن',
      subtitle:
          'حداقل ۲ عکس آپلود کن تا شروع کنی، هرچی بیشتر باشه پروفایلت بهتر '
          'دیده می‌شه. رو هر عکسی بزنی می‌تونی جاش عوض کنی یا حذفش کنی.',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _maxPhotos,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, i) {
          if (i < _photos.length) {
            return GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _PhotoEditScreen(
                    photos: _photos,
                    initialIndex: i,
                    onChanged: () => setState(() {}),
                  ),
                ));
                if (mounted) setState(() {});
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_photos[i].path), fit: BoxFit.cover),
              ),
            );
          }
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickPhoto,
            child: Container(
              decoration: BoxDecoration(
                color: _OB.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _OB.border),
              ),
              child: const Icon(Icons.add, color: Colors.white70),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      HapticFeedback.lightImpact();
      setState(() => _photos.add(file));
    }
  }

  Widget _stepBioAndPrompts() {
    return _scrollableStep(
      title: 'بیشتر راجع به خودت بگو',
      subtitle:
          'یه بیو بنویس و به یه پرامپت جواب بده تا پروفایلت دیده بشه و '
          'مکالمه راحت‌تر شروع بشه.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _menuCard(
            title: 'درباره‌ی من',
            subtitle: _hasBio
                ? _bioController.text.trim()
                : 'خودتو معرفی کن تا یه تاثیر خوب بذاری.',
            filled: _hasBio,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _AddBioScreen(controller: _bioController),
              ));
              setState(() {});
            },
          ),
          const SizedBox(height: 14),
          _menuCard(
            title: 'یه پرامپت انتخاب کن',
            subtitle: _hasPromptAnswer
                ? '$_selectedPromptText\n${_promptAnswerController.text.trim()}'
                : 'به یه پرامپت جواب بده تا شخصیتت رو نشون بدی.',
            filled: _hasPromptAnswer,
            onTap: _openPromptFlow,
          ),
        ],
      ),
    );
  }

  Future<void> _openPromptFlow() async {
    final prompts = (_serverOptions?.prompts.isNotEmpty ?? false)
        ? _serverOptions!.prompts.map((p) => OptionItem(p.id, p.text)).toList()
        : kFallbackPrompts;

    final chosen = await Navigator.of(context).push<OptionItem>(
      MaterialPageRoute(builder: (_) => _SelectPromptScreen(prompts: prompts)),
    );
    if (chosen == null || !mounted) return;

    final answer = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _AnswerPromptScreen(
          promptLabel: chosen.label,
          initialAnswer:
              _selectedPromptId == chosen.id ? _promptAnswerController.text : '',
        ),
      ),
    );
    if (answer != null && answer.trim().isNotEmpty) {
      setState(() {
        _selectedPromptId = chosen.id;
        _selectedPromptText = chosen.label;
        _promptAnswerController.text = answer.trim();
      });
    }
  }
}

/// فرمت‌کننده‌ی ورودی تاریخ تولد: هرچی کاربر با کیبرد عددی تایپ می‌کنه رو
/// می‌گیره و خودکار به‌صورت MM/DD/YYYY با «/» جدا می‌کنه (حداکثر ۸ رقم).
class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 3) buffer.write('/');
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}


/// صفحه‌ی «اضافه کردن بیو» — از منوی «بیشتر راجع به خودت بگو» باز می‌شه.
class _AddBioScreen extends StatefulWidget {
  final TextEditingController controller;
  const _AddBioScreen({required this.controller});

  @override
  State<_AddBioScreen> createState() => _AddBioScreenState();
}

class _AddBioScreenState extends State<_AddBioScreen> {
  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.controller.text.trim().isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _OB.bg,
        appBar: AppBar(
          backgroundColor: _OB.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('اضافه کردن بیو',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          actions: [
            TextButton(
              onPressed: canSubmit ? () => Navigator.of(context).pop() : null,
              child: Text('تمام',
                  style: TextStyle(
                      color: canSubmit ? Colors.white : _OB.muted,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _OB.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: widget.controller,
                  autofocus: true,
                  maxLines: 6,
                  maxLength: kOnboardingMaxBio,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'مثلاً: عاشق کوه و قهوه‌ام، دنبال یکی که...',
                    hintStyle: TextStyle(color: _OB.muted),
                    counterStyle: TextStyle(color: _OB.muted),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 14),
              _tipBox(
                title: 'راهنمای بیو',
                body:
                    'بیوهای خوب کوتاه و مشخصن. از علاقه‌مندی‌ها، ارزش‌هات و '
                    'اینکه دنبال چی هستی بگو.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _tipBox({required String title, required String body}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _OB.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      color: _OB.muted, fontSize: 12.5, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// صفحه‌ی «یه پرامپت انتخاب کن» — لیست پرامپت‌ها با خط جداکننده‌ی نازک.
class _SelectPromptScreen extends StatelessWidget {
  final List<OptionItem> prompts;
  const _SelectPromptScreen({required this.prompts});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _OB.bg,
        appBar: AppBar(
          backgroundColor: _OB.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('یه پرامپت انتخاب کن',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: prompts.length,
          separatorBuilder: (_, __) => const Divider(color: _OB.border, height: 1),
          itemBuilder: (context, i) {
            final p = prompts[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.label,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
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

/// صفحه‌ی «جواب به پرامپت» — پرامپت انتخاب‌شده بالا، باکس نوشتن پایینش.
class _AnswerPromptScreen extends StatefulWidget {
  final String promptLabel;
  final String initialAnswer;
  const _AnswerPromptScreen(
      {required this.promptLabel, required this.initialAnswer});

  @override
  State<_AnswerPromptScreen> createState() => _AnswerPromptScreenState();
}

class _AnswerPromptScreenState extends State<_AnswerPromptScreen> {
  late final _controller = TextEditingController(text: widget.initialAnswer);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _OB.bg,
        appBar: AppBar(
          backgroundColor: _OB.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('جواب به پرامپت',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          actions: [
            TextButton(
              onPressed: canSubmit
                  ? () => Navigator.of(context).pop(_controller.text.trim())
                  : null,
              child: Text('تمام',
                  style: TextStyle(
                      color: canSubmit ? Colors.white : _OB.muted,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _OB.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.promptLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.chevron_left, color: _OB.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _OB.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: kOnboardingMaxPromptAnswer,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'یه‌چیز باحال بنویس...',
                    hintStyle: TextStyle(color: _OB.muted),
                    counterStyle: TextStyle(color: _OB.muted),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 14),
              _tipBox(
                title: 'راهنمای پرامپت',
                body:
                    'پرامپت‌ها شخصیتتو نشون می‌دن. یکی رو انتخاب کن که بهت '
                    'می‌خوره و به سبک خودت جواب بده.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفحه‌ی ویرایش عکس‌ها — با زدن رو یه عکس تو گرید باز می‌شه: پیش‌نمایش
/// بزرگ، ردیف تامبنیل با ضربدر حذف، و دکمه‌ی «جایگزین کردن».
class _PhotoEditScreen extends StatefulWidget {
  final List<XFile> photos; // رفرنس مستقیم به لیست state اصلی
  final int initialIndex;
  final VoidCallback onChanged;
  const _PhotoEditScreen({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<_PhotoEditScreen> {
  late int _activeIndex = widget.initialIndex;

  Future<void> _replace() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => widget.photos[_activeIndex] = file);
    widget.onChanged();
  }

  void _removePhoto(int index) {
    setState(() {
      widget.photos.removeAt(index);
      if (_activeIndex >= widget.photos.length) {
        _activeIndex = widget.photos.length - 1;
      }
      if (_activeIndex < 0) _activeIndex = 0;
    });
    widget.onChanged();
    if (widget.photos.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _OB.bg,
        appBar: AppBar(
          backgroundColor: _OB.bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('ویرایش عکس‌ها',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('تمام',
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(widget.photos[_activeIndex].path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final selected = i == _activeIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _activeIndex = i),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    selected ? Colors.white : Colors.transparent,
                                width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(widget.photos[i].path),
                                fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => _removePhoto(i),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black87,
                              child:
                                  Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _replace,
                  child: const Text('جایگزین کردن',
                      style:
                          TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صفحه‌ی موقعیت مکانی — سبک "system permission" تیندر: بدون نوار پیشرفت
/// یا فلش برگشت، فقط آیکون/متن/دکمه‌ی «اجازه بده»، و یه بخش قابل‌بازشدن
/// «موقعیت من چطور استفاده می‌شه؟» که با زدنش توضیح «نگران نباش» میاد بالا.
class _LocationPermissionScreen extends StatefulWidget {
  final Future<void> Function() onAllow;
  const _LocationPermissionScreen({required this.onAllow});

  @override
  State<_LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<_LocationPermissionScreen> {
  bool _infoExpanded = false;
  bool _loading = false;
  String? _error;

  Future<void> _handleAllow() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onAllow();
      // موفقیت‌آمیز بود: onAllow خودش کاربر رو به HomeScreen می‌بره.
    } on NetworkException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'ارتباط با سرور برقرار نشد. دوباره امتحان کن.';
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'یه مشکلی تو اطلاعات واردشده هست. مراحل قبلی رو چک کن.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'یه مشکلی پیش اومد. دوباره امتحان کن.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_loading,
        child: Scaffold(
          backgroundColor: _OB.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                children: [
                  if (_infoExpanded)
                    Align(
                      alignment: Alignment.topCenter,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward, color: Colors.white),
                        onPressed: () => setState(() => _infoExpanded = false),
                      ),
                    ),
                  if (!_infoExpanded) ...[
                    const Spacer(),
                    const Text('اهل همین اطرافی؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    const Text(
                      'موقعیتت رو فعال کن تا آدم‌های همین اطراف یا کمی دورتر '
                      'رو ببینی. بدون این، کسی باهات مچ نمی‌شه.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _OB.muted, fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      width: 120,
                      height: 120,
                      decoration:
                          const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on_outlined,
                          color: Colors.black87, size: 52),
                    ),
                    const Spacer(),
                  ] else
                    const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: _loading ? null : _handleAllow,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black54))
                          : const Text('اجازه بده',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  if (!_infoExpanded)
                    InkWell(
                      onTap: () => setState(() => _infoExpanded = true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('موقعیت من چطور استفاده می‌شه؟',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          SizedBox(width: 6),
                          Icon(Icons.keyboard_arrow_down,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    )
                  else ...[
                    const SizedBox(height: 20),
                    const Text('نگران نباش—',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    const Text(
                      'موقعیتت کمک می‌کنه افرادی که نزدیکت یا کمی دورترن رو '
                      'بهت پیشنهاد بدیم. موقعیت دقیقت هیچ‌وقت به اشتراک '
                      'گذاشته نمی‌شه.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _OB.muted, fontSize: 14, height: 1.6),
                    ),
                    const Spacer(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
