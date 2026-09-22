import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../auth_session.dart';
import '../models/profile_models.dart';
import '../onboarding/onboarding_data.dart';
import '../style/app_colors.dart';
import 'bio_prompt_screens.dart';
import 'education_screen.dart';
import 'identity_screens.dart';
import 'interests_editor_screen.dart';
import 'living_in_screen.dart';
import 'photo_grid_editor_screen.dart';
import 'preview_profile_screen.dart';
import 'private_photos_screen.dart';
import 'profile_sheets.dart';
import 'start_screen.dart';

/// صفحه‌ی «پروفایل من» — همون چیزی که با زدن تب Profile تو نوار پایین باز
/// می‌شه. ساختارش دقیقاً از روی اسکرین‌شات‌های تیندر کپی شده:
/// آواتار + Preview بالا، هشدار «Complete your profile»، ردیف پیل‌های
/// قابل‌ویرایش (Living in / Height / Job / ...)، My Photos، My Prompts،
/// My Interests، و بنر Gold/آمار پایین.
///
/// ساده‌سازی عمدی نسبت به اپ واقعی: ردیف پیل‌ها تو تیندر دو ردیفه و با
/// اسکرول افقی جابه‌جا می‌شه؛ اینجا برای سادگی یه ردیف تک‌خطی اسکرول‌شونده
/// است — همه‌ی پیل‌ها هستن، فقط چیدمانشون فرق داره.
class ProfileHomeScreen extends StatefulWidget {
  const ProfileHomeScreen({super.key});

  @override
  State<ProfileHomeScreen> createState() => _ProfileHomeScreenState();
}

class _ProfileHomeScreenState extends State<ProfileHomeScreen> {
  ProfileOptions? _options;
  MyProfile? _profile;
  String? _error;

  // --- کپی محلیِ قابل‌ویرایش از فیلدهای پروفایل ---
  List<Photo> _photos = [];
  final Set<String> _interests = {};
  List<PromptAnswer> _prompts = [];
  List<String> _genders = [];
  bool _showGenderOnProfile = true;
  List<String> _orientations = [];
  bool _showOrientationOnProfile = false;
  String? _lookingFor;
  String? _educationLevel;
  String? _school;
  Map<String, String> _lifestyle = {};
  Map<String, String> _aboutYou = {};
  int? _heightCm;
  String? _jobTitle;
  String? _jobCompany;
  String? _cityName;
  bool _showCityOnProfile = true;
  String? _wantChildren;
  List<String> _languages = [];
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        ApiClient.fetchProfileOptions(),
        ApiClient.fetchMyProfile(),
      ]);
      final options = results[0] as ProfileOptions;
      final profile = results[1] as MyProfile;
      setState(() {
        _options = options;
        _profile = profile;
        _photos = profile.photos;
        _interests
          ..clear()
          ..addAll(profile.interests);
        _prompts = List.of(profile.prompts);
        _genders = List.of(profile.genders);
        _showGenderOnProfile = profile.showGenderOnProfile;
        _orientations = List.of(profile.sexualOrientations);
        _showOrientationOnProfile = profile.showOrientationOnProfile;
        _lookingFor = profile.lookingFor;
        _educationLevel = profile.educationLevel;
        _school = profile.school;
        _lifestyle = Map.of(profile.lifestyle);
        _aboutYou = Map.of(profile.aboutYou);
        _heightCm = profile.heightCm;
        _jobTitle = profile.jobTitle;
        _jobCompany = profile.jobCompany;
        _cityName = profile.cityName;
        _showCityOnProfile = profile.showCityOnProfile;
        _wantChildren = profile.wantChildren;
        _languages = List.of(profile.languages);
        _bio = profile.bio;
      });
    } catch (e) {
      setState(() => _error = 'دریافت اطلاعات پروفایل با مشکل مواجه شد.');
    }
  }

  Future<void> _persist() async {
    final p = _profile;
    if (p == null) return;
    final input = ProfileInput(
      name: p.name,
      birthDate: p.birthDate,
      gender: _genders.isNotEmpty ? _genders.first : p.gender,
      interestedIn: p.interestedInMulti.isNotEmpty ? p.interestedInMulti.first : p.interestedIn,
      bio: _bio,
      interests: _interests.toList(),
      prompts: _prompts,
      genders: _genders,
      showGenderOnProfile: _showGenderOnProfile,
      sexualOrientations: _orientations,
      showOrientationOnProfile: _showOrientationOnProfile,
      interestedInMulti: p.interestedInMulti,
      lookingFor: _lookingFor,
      educationLevel: _educationLevel,
      school: _school,
      lifestyle: _lifestyle,
      aboutYou: _aboutYou,
      heightCm: _heightCm,
      jobTitle: _jobTitle,
      jobCompany: _jobCompany,
      cityName: _cityName,
      showCityOnProfile: _showCityOnProfile,
      wantChildren: _wantChildren,
      languages: _languages,
    );
    try {
      await ApiClient.saveProfile(input);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ذخیره‌سازی با مشکل مواجه شد. دوباره امتحان کن.')));
      }
    }
  }

  int get _basicsFilledCount =>
      [_aboutYou['zodiac'], _educationLevel, _wantChildren, _aboutYou['communication'], _aboutYou['love_language']]
          .where((v) => v != null)
          .length;

  int get _lifestyleFilledCount => kLifestyleCategories.where((c) => _lifestyle[c.id] != null).length;

  bool get _profileComplete =>
      (_cityName?.isNotEmpty ?? false) &&
      _heightCm != null &&
      (_jobTitle?.isNotEmpty ?? false) &&
      (_school?.isNotEmpty ?? false) &&
      _genders.isNotEmpty &&
      _basicsFilledCount >= kAboutYouCategories.length + 2 &&
      _lifestyleFilledCount >= kLifestyleCategories.length &&
      _lookingFor != null &&
      _languages.isNotEmpty;

  Map<String, String> get _promptTextMap {
    final map = <String, String>{};
    for (final p in _options?.prompts ?? const <PromptOption>[]) {
      map[p.id] = p.text;
    }
    for (final p in kFallbackPrompts) {
      map.putIfAbsent(p.id, () => p.label);
    }
    return map;
  }

  Map<String, String> get _interestLabelMap {
    if (_options == null) return {};
    return {for (final i in _options!.interests) i.id: i.label};
  }

  MyProfile get _liveProfile {
    final p = _profile!;
    return MyProfile(
      name: p.name,
      birthDate: p.birthDate,
      age: p.age,
      gender: p.gender,
      interestedIn: p.interestedIn,
      bio: _bio,
      interests: _interests.toList(),
      prompts: _prompts,
      photos: _photos,
      publicId: p.publicId,
      genders: _genders,
      showGenderOnProfile: _showGenderOnProfile,
      sexualOrientations: _orientations,
      showOrientationOnProfile: _showOrientationOnProfile,
      interestedInMulti: p.interestedInMulti,
      lookingFor: _lookingFor,
      educationLevel: _educationLevel,
      school: _school,
      lifestyle: _lifestyle,
      aboutYou: _aboutYou,
      heightCm: _heightCm,
      jobTitle: _jobTitle,
      jobCompany: _jobCompany,
      cityName: _cityName,
      showCityOnProfile: _showCityOnProfile,
      wantChildren: _wantChildren,
      languages: _languages,
    );
  }

  // ---------------------------------------------------------------------
  // اکشن‌های پیل‌ها
  // ---------------------------------------------------------------------

  Future<void> _editLivingIn() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => LivingInScreen(initialCity: _cityName)),
    );
    if (result == null) return;
    setState(() {
      _cityName = result;
      _showCityOnProfile = result.isNotEmpty;
    });
    _persist();
  }

  Future<void> _editHeight() async {
    final result = await showHeightSheet(context, initialCm: _heightCm);
    if (result == null) return;
    setState(() => _heightCm = result == -1 ? null : result);
    _persist();
  }

  Future<void> _editJob() async {
    final result = await showJobSheet(context, initialTitle: _jobTitle, initialCompany: _jobCompany);
    if (result == null) return;
    setState(() {
      _jobTitle = result['title'];
      _jobCompany = result['company'];
    });
    _persist();
  }

  Future<void> _editEducation() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => EditSchoolInfoScreen(initialSchool: _school)),
    );
    if (result == null) return;
    setState(() => _school = result);
    _persist();
  }

  Future<void> _editIdentity() async {
    final result = await showIdentitySheet(
      context,
      genders: _genders,
      showGenderOnProfile: _showGenderOnProfile,
      orientations: _orientations,
      showOrientationOnProfile: _showOrientationOnProfile,
    );
    if (result == null) return;
    setState(() {
      _genders = result.genders;
      _showGenderOnProfile = result.showGenderOnProfile;
      _orientations = result.orientations;
      _showOrientationOnProfile = result.showOrientationOnProfile;
    });
    _persist();
  }

  Future<void> _editBasics() async {
    final result = await showBasicsSheet(
      context,
      zodiac: _aboutYou['zodiac'],
      educationLevel: _educationLevel,
      wantChildren: _wantChildren,
      communication: _aboutYou['communication'],
      loveLanguage: _aboutYou['love_language'],
    );
    if (result == null) return;
    setState(() {
      final updated = Map<String, String>.of(_aboutYou);
      void setOrRemove(String key, String? value) {
        if (value == null) {
          updated.remove(key);
        } else {
          updated[key] = value;
        }
      }

      setOrRemove('zodiac', result.zodiac);
      setOrRemove('communication', result.communication);
      setOrRemove('love_language', result.loveLanguage);
      _aboutYou = updated;
      _educationLevel = result.educationLevel;
      _wantChildren = result.wantChildren;
    });
    _persist();
  }

  Future<void> _editLifestyle() async {
    final result = await showLifestyleSheet(context, _lifestyle);
    if (result == null) return;
    setState(() => _lifestyle = result);
    _persist();
  }

  Future<void> _editLookingFor() async {
    final result = await showLookingForSheet(context, initial: _lookingFor);
    if (result == null) return;
    setState(() => _lookingFor = result);
    _persist();
  }

  Future<void> _editLanguages() async {
    final result = await showLanguagesSheet(context, _languages);
    if (result == null) return;
    setState(() => _languages = result);
    _persist();
  }

  Future<void> _editPhotos() async {
    final maxPhotos = _options?.limits.maxPhotos ?? 9;
    final result = await Navigator.of(context).push<List<Photo>>(
      MaterialPageRoute(builder: (_) => PhotoGridEditorScreen(initialPhotos: _photos, maxPhotos: maxPhotos)),
    );
    if (result != null) setState(() => _photos = result);
  }

  Future<void> _editBio() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => BioEditScreen(initialBio: _bio)),
    );
    if (result == null) return;
    setState(() => _bio = result);
    _persist();
  }

  List<OptionItem> get _promptChoices => (_options?.prompts.isNotEmpty ?? false)
      ? _options!.prompts.map((p) => OptionItem(p.id, p.text)).toList()
      : kFallbackPrompts;

  Future<void> _addOrEditPrompt([PromptAnswer? existing]) async {
    OptionItem chosen;
    if (existing == null) {
      final picked = await Navigator.of(context).push<OptionItem>(
        MaterialPageRoute(builder: (_) => PromptSelectScreen(prompts: _promptChoices)),
      );
      if (picked == null) return;
      chosen = picked;
    } else {
      chosen = OptionItem(existing.promptId, _promptTextMap[existing.promptId] ?? '');
    }

    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => PromptAnswerScreen(
          promptId: chosen.id,
          promptLabel: chosen.label,
          initialAnswer: existing?.answer ?? '',
          prompts: _promptChoices,
        ),
      ),
    );
    if (result == null) return;

    setState(() {
      _prompts = [
        ..._prompts.where((p) => p.promptId != (existing?.promptId ?? '') && p.promptId != result['prompt_id']),
        PromptAnswer(promptId: result['prompt_id']!, answer: result['answer']!),
      ];
    });
    _persist();
  }

  Future<void> _editInterests() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(builder: (_) => InterestsEditorScreen(initialInterests: _interests)),
    );
    if (result == null) return;
    setState(() {
      _interests
        ..clear()
        ..addAll(result);
    });
    _persist();
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDark.cardAlt,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('خروج از حساب', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await AuthSession.clear();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                  (route) => false,
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppDark.bg,
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('تلاش دوباره')),
          ]),
        ),
      );
    }
    if (_options == null || _profile == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.white,
      backgroundColor: AppDark.card,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _buildTopBar(),
          const SizedBox(height: 16),
          if (!_profileComplete) _buildCompleteBanner(),
          const SizedBox(height: 12),
          _buildPillRow(),
          const SizedBox(height: 24),
          _buildPhotosSection(),
          const SizedBox(height: 20),
          _buildPrivatePhotosSection(),
          const SizedBox(height: 20),
          _buildPromptsSection(),
          const SizedBox(height: 20),
          _buildInterestsSection(),
          const SizedBox(height: 20),
          _buildGoldBanner(),
          const SizedBox(height: 12),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final thumb = _photos.isNotEmpty ? '$backendBaseUrl${_photos.first.url}' : null;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 56,
            height: 56,
            child: thumb == null
                ? Container(color: AppDark.card, child: const Icon(Icons.person, color: AppDark.muted))
                : Image.network(thumb, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(_profile!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: Color(0xFF3D9CF0), size: 18),
              ]),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PreviewProfileScreen(
                      profile: _liveProfile,
                      promptTextMap: _promptTextMap,
                      interestLabelMap: _interestLabelMap,
                    ),
                  ));
                },
                child: const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('پیش‌نمایش  ›', style: TextStyle(color: AppDark.muted, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: _openSettingsSheet,
        ),
      ],
    );
  }

  Widget _buildCompleteBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
      child: const Row(children: [
        Icon(Icons.error, color: AppDark.warning, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text('پروفایلت رو کامل کن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildPillRow() {
    Widget pill({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool filled = true,
      bool showDot = false,
    }) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 10),
        child: Stack(clipBehavior: Clip.none, children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (!filled) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.add, size: 14, color: AppDark.muted),
                ],
              ]),
            ),
          ),
          if (showDot)
            const Positioned(
              top: -2,
              right: 2,
              child: CircleAvatar(radius: 4, backgroundColor: AppDark.warning),
            ),
        ]),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          pill(
            icon: Icons.home_outlined,
            label: (_cityName?.isNotEmpty ?? false) ? _cityName! : 'زندگی در',
            filled: _cityName?.isNotEmpty ?? false,
            onTap: _editLivingIn,
          ),
          pill(
            icon: Icons.straighten,
            label: _heightCm != null ? '${_heightCm}cm' : 'قد',
            filled: _heightCm != null,
            onTap: _editHeight,
          ),
          pill(
            icon: Icons.work_outline,
            label: (_jobTitle?.isNotEmpty ?? false) ? _jobTitle! : 'شغل',
            filled: _jobTitle?.isNotEmpty ?? false,
            showDot: !(_jobTitle?.isNotEmpty ?? false),
            onTap: _editJob,
          ),
          pill(
            icon: Icons.school_outlined,
            label: (_school?.isNotEmpty ?? false) ? _school! : 'تحصیلات',
            filled: _school?.isNotEmpty ?? false,
            showDot: !(_school?.isNotEmpty ?? false),
            onTap: _editEducation,
          ),
          pill(
            icon: Icons.wc_outlined,
            label: 'جنسیت، گرایش',
            onTap: _editIdentity,
          ),
          pill(
            icon: Icons.extension_outlined,
            label: 'Basics (${_basicsFilledCount}/${kAboutYouCategories.length + 2})',
            onTap: _editBasics,
          ),
          pill(
            icon: Icons.local_bar_outlined,
            label: 'Lifestyle (${_lifestyleFilledCount}/${kLifestyleCategories.length})',
            onTap: _editLifestyle,
          ),
          pill(
            icon: Icons.search,
            label: optionLabel(kLookingForOptions, _lookingFor) ?? 'دنبال چی هستی',
            filled: _lookingFor != null,
            onTap: _editLookingFor,
          ),
          pill(
            icon: Icons.translate,
            label: _languages.isEmpty ? 'زبان‌ها' : '${_languages.length} زبان',
            filled: _languages.isNotEmpty,
            onTap: _editLanguages,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800));

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('عکس‌های من'),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: Row(children: [
            Expanded(
              child: _photos.isEmpty
                  ? _dashedAddBox(onTap: _editPhotos)
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network('$backendBaseUrl${_photos[i].url}', width: 72, fit: BoxFit.cover),
                      ),
                    ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        _editLink('ویرایش عکس‌ها', _editPhotos),
      ],
    );
  }

  Widget _buildPrivatePhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Icon(Icons.lock_outline, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('عکس‌های خصوصی من', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        const Text('این عکس‌ها هیچ‌وقت پابلیک نمی‌شن؛ فقط با اجازه‌ی تو دیده می‌شن.',
            style: TextStyle(color: AppDark.muted, fontSize: 12.5)),
        const SizedBox(height: 10),
        _editLink('مدیریت عکس‌های خصوصی', () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivatePhotosScreen()));
        }),
      ],
    );
  }

  Widget _dashedAddBox({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: AppDark.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppDark.border),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _editLink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Text(text, style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPromptsSection() {
    final maxPrompts = _options?.limits.maxPrompts ?? 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('My Prompts'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _promptCard(title: 'درباره‌ی من', body: _bio, onTap: _editBio)),
          const SizedBox(width: 12),
          Expanded(
            child: _prompts.isNotEmpty
                ? _promptCard(
                    title: _promptTextMap[_prompts.first.promptId] ?? '',
                    body: _prompts.first.answer,
                    onTap: () => _addOrEditPrompt(_prompts.first),
                  )
                : _addPromptCard(),
          ),
        ]),
        if (_prompts.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _prompts
                  .skip(1)
                  .map((p) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 52) / 2,
                        child: _promptCard(
                          title: _promptTextMap[p.promptId] ?? '',
                          body: p.answer,
                          onTap: () => _addOrEditPrompt(p),
                        ),
                      ))
                  .toList(),
            ),
          ),
        if (_prompts.length + 1 < maxPrompts)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(width: (MediaQuery.of(context).size.width - 52) / 2, child: _addPromptCard()),
          ),
      ],
    );
  }

  Widget _promptCard({required String title, required String body, required VoidCallback onTap}) {
    return Stack(children: [
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 150,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppDark.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Expanded(
                child: Text(body.isEmpty ? '—' : body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        bottom: 8,
        left: 8,
        child: GestureDetector(
          onTap: onTap,
          child: const CircleAvatar(
            radius: 13,
            backgroundColor: Colors.black54,
            child: Icon(Icons.edit, size: 13, color: Colors.white),
          ),
        ),
      ),
    ]);
  }

  Widget _addPromptCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _addOrEditPrompt(),
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDark.border),
        ),
        child: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_circle_outline, color: Colors.white),
            SizedBox(height: 8),
            Text('یه پرامپت انتخاب کن', style: TextStyle(color: AppDark.muted, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildInterestsSection() {
    final labelMap = _interestLabelMap;
    String labelOf(String id) {
      final fromApi = labelMap[id];
      if (fromApi != null) return fromApi;
      for (final cat in kInterestCategories) {
        final l = optionLabel(cat.items, id);
        if (l != null) return l;
      }
      return id;
    }

    final list = _interests.toList();
    final summary = list.isEmpty
        ? 'انتخاب کن'
        : list.length == 1
            ? labelOf(list.first)
            : '${labelOf(list.first)}، +${list.length - 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('My Interests'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _interestsCard(
              title: 'الان به این علاقه دارم',
              body: summary,
              onTap: _editInterests,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _interestsCard(
              title: 'مشغول گوش دادن به',
              body: 'انتخاب آهنگ',
              onTap: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('این قابلیت به‌زودی اضافه می‌شه.'))),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _interestsCard({required String title, required String body, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppDark.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Text(body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldBanner() {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('این قابلیت به‌زودی اضافه می‌شه.'))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFB8860B), borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          Expanded(
            child: Text('Tinder Gold — ببین کی لایکت کرده، سریع‌تر متچ شو',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          Icon(Icons.arrow_back, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _buildStatsRow() {
    Widget stat(String label) => Expanded(
          child: Column(children: [
            const Text('۰', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppDark.muted, fontSize: 11), textAlign: TextAlign.center),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: AppDark.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        stat('سوپرلایک'),
        stat('بوست'),
        stat('اشتراک'),
      ]),
    );
  }
}
