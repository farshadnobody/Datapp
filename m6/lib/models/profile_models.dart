class Option {
  final String id;
  final String label;
  Option({required this.id, required this.label});

  factory Option.fromJson(Map<String, dynamic> json) =>
      Option(id: json['id'], label: json['label']);
}

class PromptOption {
  final String id;
  final String text;
  PromptOption({required this.id, required this.text});

  factory PromptOption.fromJson(Map<String, dynamic> json) =>
      PromptOption(id: json['id'], text: json['text']);
}

class ProfileLimits {
  final int minAge;
  final int maxAge;
  final int minInterests;
  final int maxInterests;
  final int maxPrompts;
  final int maxBioLength;
  final int maxNameLength;
  final int maxPhotos;

  ProfileLimits({
    required this.minAge,
    required this.maxAge,
    required this.minInterests,
    required this.maxInterests,
    required this.maxPrompts,
    required this.maxBioLength,
    required this.maxNameLength,
    required this.maxPhotos,
  });

  factory ProfileLimits.fromJson(Map<String, dynamic> json) => ProfileLimits(
        minAge: json['min_age'],
        maxAge: json['max_age'],
        minInterests: json['min_interests'],
        maxInterests: json['max_interests'],
        maxPrompts: json['max_prompts'],
        maxBioLength: json['max_bio_length'],
        maxNameLength: json['max_name_length'],
        maxPhotos: json['max_photos'],
      );
}

class ProfileOptions {
  final List<Option> genders;
  final List<Option> interestedIn;
  final List<Option> interests;
  final List<PromptOption> prompts;
  final ProfileLimits limits;

  ProfileOptions({
    required this.genders,
    required this.interestedIn,
    required this.interests,
    required this.prompts,
    required this.limits,
  });

  factory ProfileOptions.fromJson(Map<String, dynamic> json) => ProfileOptions(
        genders: (json['genders'] as List).map((e) => Option.fromJson(e)).toList(),
        interestedIn: (json['interested_in'] as List)
            .map((e) => Option.fromJson(e))
            .toList(),
        interests:
            (json['interests'] as List).map((e) => Option.fromJson(e)).toList(),
        prompts: (json['prompts'] as List)
            .map((e) => PromptOption.fromJson(e))
            .toList(),
        limits: ProfileLimits.fromJson(json['limits']),
      );
}

class PromptAnswer {
  final String promptId;
  final String answer;
  PromptAnswer({required this.promptId, required this.answer});

  factory PromptAnswer.fromJson(Map<String, dynamic> json) =>
      PromptAnswer(promptId: json['prompt_id'], answer: json['answer']);

  Map<String, dynamic> toJson() => {'prompt_id': promptId, 'answer': answer};
}

class ProfileInput {
  final String name;
  final String birthDate; // فرمت: YYYY-MM-DD
  final String gender;
  final String interestedIn;
  final String bio;
  final List<String> interests;
  final List<PromptAnswer> prompts;

  // --- فیلدهای جدید اونبوردینگ (سبک تیندر) ---
  // همه‌شون اختیاری‌ان تا کدهای قبلی (مثل edit_profile_screen.dart) بدون
  // تغییر کامپایل بشن. برای این‌که واقعاً ذخیره بشن، باید ستون/فیلد معادل
  // رو تو بک‌اند (Go) هم اضافه کنی — الان فقط تو JSON خروجی می‌رن.
  final List<String> genders; // چندانتخابی (Man/Woman/Beyond Binary/...)
  final bool showGenderOnProfile;
  final List<String> sexualOrientations;
  final bool showOrientationOnProfile;
  final List<String> interestedInMulti; // Men/Women/Beyond Binary/Everyone
  final String? lookingFor; // هدف رابطه (تک‌انتخابی)
  final String? educationLevel;
  final String? school;
  final Map<String, String> lifestyle; // مثلا {"drinking": "socially", ...}
  final Map<String, String> aboutYou; // مثلا {"communication": "phone_caller", ...}

  // --- فیلدهای جدید صفحه‌ی «پروفایل من» (قد/شغل/تحصیلات/شهر/بچه/زبان) ---
  // مثل بالا: همه اختیاری‌ان، فقط تو JSON خروجی می‌رن؛ برای ذخیره‌ی واقعی
  // باید ستون معادل تو بک‌اند (Go) هم اضافه بشه.
  final int? heightCm;
  final String? jobTitle;
  final String? jobCompany;
  final String? cityName; // برچسب نمایشی «زندگی در ...» (نه مختصات)
  final bool showCityOnProfile;
  final String? wantChildren;
  // null = «کلید رو نفرست» (سرور مقدار قبلی رو دست‌نخورده نگه می‌داره)؛ [] = «همه‌ی
  // زبان‌ها پاک بشن». صفحه‌هایی که زبان رو نمی‌شناسن (اونبوردینگ، ویرایش قدیمی) null می‌ذارن.
  final List<String>? languages;

  ProfileInput({
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    required this.interests,
    required this.prompts,
    this.genders = const [],
    this.showGenderOnProfile = true,
    this.sexualOrientations = const [],
    this.showOrientationOnProfile = false,
    this.interestedInMulti = const [],
    this.lookingFor,
    this.educationLevel,
    this.school,
    this.lifestyle = const {},
    this.aboutYou = const {},
    this.heightCm,
    this.jobTitle,
    this.jobCompany,
    this.cityName,
    this.showCityOnProfile = true,
    this.wantChildren,
    this.languages,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'birth_date': birthDate,
        'gender': gender,
        'interested_in': interestedIn,
        'bio': bio,
        'interests': interests,
        'prompts': prompts.map((p) => p.toJson()).toList(),
        'genders': genders,
        'show_gender_on_profile': showGenderOnProfile,
        'sexual_orientations': sexualOrientations,
        'show_orientation_on_profile': showOrientationOnProfile,
        'interested_in_multi': interestedInMulti,
        // خالی ('') = «پاکش کن» — null هم یعنی کاربر مقداری نداره، پس همیشه می‌فرستیم.
        'looking_for': lookingFor ?? '',
        'education_level': educationLevel ?? '',
        'school': school ?? '',
        'lifestyle': lifestyle,
        'about_you': aboutYou,
        'height_cm': heightCm ?? 0, // ۰ = پاک کردن
        if (jobTitle != null) 'job_title': jobTitle, // خالی = پاک کردن
        if (jobCompany != null) 'job_company': jobCompany,
        if (cityName != null) 'city_name': cityName,
        'show_city_on_profile': showCityOnProfile,
        'want_children': wantChildren ?? '',
        if (languages != null) 'languages': languages,
      };
}

class Photo {
  final String id;
  final String url; // مسیر نسبیه (مثلاً "/uploads/xxxx.jpg")، باید با
  // backendBaseUrl ترکیب بشه.
  final int position;

  Photo({required this.id, required this.url, required this.position});

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
        id: json['id'],
        url: json['url'],
        position: json['position'],
      );
}

// PrivatePhoto عمداً یه کلاس کاملاً جداست (نه همون Photo با یه فلگ) — چون
// عکس‌های خصوصی نه position دارن نه primary، و آدرسشون هم به یه endpoint
// احرازهویت‌شده اشاره می‌کنه، نه یه مسیر استاتیک باز.
class PrivatePhoto {
  final String id;
  final String url;

  PrivatePhoto({required this.id, required this.url});

  factory PrivatePhoto.fromJson(Map<String, dynamic> json) =>
      PrivatePhoto(id: json['id'], url: json['url']);
}

class MyProfile {
  final String name;
  final String birthDate; // YYYY-MM-DD
  final int age;
  final String gender;
  final String interestedIn;
  final String bio;
  final List<String> interests;
  List<PromptAnswer> prompts; // جزئیات: با زدنِ فلشِ کارت پر می‌شه (applyDetails)
  final List<Photo> photos;
  final String publicId;

  // --- همون فیلدهای اختیاری صفحه‌ی «پروفایل من» — اگه بک‌اند نفرستدشون،
  // مقدار پیش‌فرض (null/خالی) می‌گیرن و اپ خراب نمی‌شه. ---
  final List<String> genders;
  final bool showGenderOnProfile;
  final List<String> sexualOrientations;
  final bool showOrientationOnProfile;
  final List<String> interestedInMulti;
  final String? lookingFor;
  final String? educationLevel;
  final String? school;
  final Map<String, String> lifestyle;
  final Map<String, String> aboutYou;
  final int? heightCm;
  final String? jobTitle;
  final String? jobCompany;
  final String? cityName;
  final bool showCityOnProfile;
  final String? wantChildren;
  final List<String> languages;

  MyProfile({
    required this.name,
    required this.birthDate,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    required this.interests,
    required this.prompts,
    required this.photos,
    required this.publicId,
    this.genders = const [],
    this.showGenderOnProfile = true,
    this.sexualOrientations = const [],
    this.showOrientationOnProfile = false,
    this.interestedInMulti = const [],
    this.lookingFor,
    this.educationLevel,
    this.school,
    this.lifestyle = const {},
    this.aboutYou = const {},
    this.heightCm,
    this.jobTitle,
    this.jobCompany,
    this.cityName,
    this.showCityOnProfile = true,
    this.wantChildren,
    this.languages = const [],
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) => MyProfile(
        name: json['name'],
        birthDate: json['birth_date'],
        age: json['age'],
        gender: json['gender'],
        interestedIn: json['interested_in'],
        bio: json['bio'] ?? '',
        interests: List<String>.from(json['interests'] ?? []),
        prompts: (json['prompts'] as List? ?? [])
            .map((e) => PromptAnswer.fromJson(e))
            .toList(),
        // کارتِ سبک: عکس‌ها فقط رشته‌ی آدرسن؛ کارتِ کامل: آبجکت.
        photos: [
          for (final e in (json['photos'] as List? ?? const []).asMap().entries)
            e.value is String
                ? Photo(id: '', url: e.value as String, position: e.key)
                : Photo.fromJson(e.value),
        ],
        publicId: json['public_id'] ?? '',
        genders: List<String>.from(json['genders'] ?? []),
        showGenderOnProfile: json['show_gender_on_profile'] ?? true,
        sexualOrientations: List<String>.from(json['sexual_orientations'] ?? []),
        showOrientationOnProfile: json['show_orientation_on_profile'] ?? false,
        interestedInMulti: List<String>.from(json['interested_in_multi'] ?? []),
        lookingFor: _nullIfEmpty(json['looking_for'] as String?),
        educationLevel: _nullIfEmpty(json['education_level'] as String?),
        school: _nullIfEmpty(json['school'] as String?),
        lifestyle: _stringMap(json['lifestyle']),
        aboutYou: _stringMap(json['about_you']),
        heightCm: json['height_cm'] as int?,
        jobTitle: _nullIfEmpty(json['job_title'] as String?),
        jobCompany: _nullIfEmpty(json['job_company'] as String?),
        cityName: _nullIfEmpty(json['city_name'] as String?),
        showCityOnProfile: json['show_city_on_profile'] ?? true,
        wantChildren: _nullIfEmpty(json['want_children'] as String?),
        languages: List<String>.from(json['languages'] ?? []),
      );
}

Map<String, String> _stringMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val.toString()));
  }
  return const {};
}

class DiscoveryCandidate {
  final String publicId;
  // «صورتِ کارت» (name/age/bio/interests/photos/version) عمداً final نیست: وقتی کاربر
  // فلشِ کارت رو می‌زنه و سرور می‌گه نسخه‌ی کارت عوض شده، کل کارت همین‌جا به‌روز می‌شه
  // (applyServerProfile).
  String name;
  int age;
  String bio;
  List<String> interests;
  List<PromptAnswer> prompts;
  List<Photo> photos;
  // کیلومترِ کاملِ گردشده، وابسته به بیننده → تو CardCache نمی‌ره؛ هر بار از سرور.
  double? distanceKm;

  /// نسخه‌ی کارت = profiles.updated_at سرور به میلی‌ثانیه (UnixMilli). CardCache با همین
  /// تصمیم می‌گیره کارت دوباره دانلود بشه یا نه. اگه سرور نفرستاد 0.
  int version;

  // null یعنی هیچ‌وقت swipe نشده. بعد از «برداشتنِ لایک» تو همین session صفر می‌شه.
  String? previousDirection;

  // --- فیلدهای اختیاریِ کارت سبک تیندر ---
  // اگه بک‌اند (Go) این‌ها رو تو JSON بفرسته، روی کارت نشون داده می‌شن؛
  // اگه نفرسته، فقط همون بخش از کارت نمایش داده نمی‌شه (اپ خراب نمی‌شه).
  String? lookingFor; // مثلاً "long_term"
  String? educationLevel;
  Map<String, String> lifestyle; // {"drinking": "sober", ...}
  Map<String, String> aboutYou; // {"communication": "phone_caller", ...}
  String? activityStatus; // 'active' | 'recent' | 'new' | null
  String? wantChildren; // مثلاً "want_children" — برای دسته‌ی «بچه می‌خوام» تو اکسپلور
  String? school;
  int? heightCm;
  String? jobTitle;
  String? jobCompany;
  String? cityName; // فقط وقتی خودِ کاربر اجازه‌ی نمایش داده باشه از سرور میاد
  List<String> languages;

  /// false = کارتِ «سبک» (فقط شناسه، نام، سن، درباره، علایق، عکس‌ها). جزئیات (پرامپت،
  /// سبک زندگی، تحصیلات...) با زدنِ فلشِ کارت از /api/discovery/profile گرفته می‌شه.
  bool detailsLoaded;

  /// فقط تو همین session (تو کش نمی‌ره): آیا برای این کارت، بعد از زدنِ فلش، با سرور
  /// نسخه‌ها مقایسه شده؟ جزئیاتِ کش‌شده هم یه بار با سرور چک می‌شه.
  bool detailsChecked = false;

  /// جزئیاتِ گرفته‌شده از سرور رو روی همین کارت می‌ذاره.
  void applyDetails(DiscoveryCandidate full) {
    prompts = full.prompts;
    lookingFor = full.lookingFor;
    educationLevel = full.educationLevel;
    lifestyle = full.lifestyle;
    aboutYou = full.aboutYou;
    activityStatus = full.activityStatus;
    wantChildren = full.wantChildren;
    school = full.school;
    heightCm = full.heightCm;
    jobTitle = full.jobTitle;
    jobCompany = full.jobCompany;
    cityName = full.cityName;
    languages = full.languages;
    detailsLoaded = true;
  }

  /// پاسخِ /api/discovery/profile?id=..&v=<نسخه>&d=<جزئیات رو دارم> رو روی همین کارت می‌ذاره.
  ///  - full=true (نسخه‌ی اپ کهنه بود): صورتِ کارت (اسم، سن، عکس‌ها، بیو، علایق)، version و
  ///    جزئیات همه جایگزین می‌شن.
  ///  - full=false و details_included=false (نسخه یکی بود و اپ جزئیات رو داشت): هیچ‌چیزِ
  ///    کارت عوض نمی‌شه؛ فقط وضعیتِ وابسته به بیننده (previous_direction/super_liked_me).
  ///  - full=false بدونِ details_included=false: صورتِ کارت همونه، جزئیات جایگزین می‌شن.
  /// برمی‌گردونه true اگه چیزی از محتوای کارت یا جزئیاتش عوض شده (یعنی کش باید به‌روز شه).
  bool applyServerProfile(Map<String, dynamic> json) {
    final isFull = json['full'] == true;
    final detailsIncluded = json['details_included'] != false;
    if (isFull) {
      name = json['name'] as String? ?? name;
      age = (json['age'] as num?)?.toInt() ?? age;
      bio = json['bio'] as String? ?? '';
      interests = List<String>.from(json['interests'] ?? const []);
      photos = _photosFrom(json['photos']);
      version = (json['version'] as num?)?.toInt() ?? version;
    }
    if (detailsIncluded) {
      prompts = (json['prompts'] as List? ?? const [])
          .map((e) => PromptAnswer.fromJson(e))
          .toList();
      lookingFor = _nullIfEmpty(json['looking_for'] as String?);
      educationLevel = _nullIfEmpty(json['education_level'] as String?);
      school = _nullIfEmpty(json['school'] as String?);
      lifestyle = _stringMap(json['lifestyle']);
      aboutYou = _stringMap(json['about_you']);
      wantChildren = _nullIfEmpty(json['want_children'] as String?);
      heightCm = (json['height_cm'] as num?)?.toInt();
      jobTitle = _nullIfEmpty(json['job_title'] as String?);
      jobCompany = _nullIfEmpty(json['job_company'] as String?);
      cityName = _nullIfEmpty(json['city_name'] as String?);
      languages = List<String>.from(json['languages'] ?? const []);
    }
    if (json.containsKey('previous_direction')) {
      previousDirection = json['previous_direction'] as String?;
    }
    if (json.containsKey('super_liked_me')) {
      superLikedMe = json['super_liked_me'] == true;
    }
    if (json.containsKey('distance_km')) {
      distanceKm = (json['distance_km'] as num?)?.toDouble();
    }
    if (detailsIncluded) detailsLoaded = true;
    return isFull || detailsIncluded;
  }

  /// true فقط وقتی بک‌اند تأیید کرده که این آدم واقعاً (تو دیتابیس) کاربرِ فعلی رو
  /// سوپرلایک کرده و هنوز متچ/آنمتچ/بلاکی نیست. هیچ‌وقت از استیت لوکال ساخته
  /// نمی‌شه.
  bool superLikedMe;

  DiscoveryCandidate({
    required this.publicId,
    required this.name,
    required this.age,
    required this.bio,
    required this.interests,
    required this.prompts,
    required this.photos,
    required this.distanceKm,
    this.version = 0,
    this.previousDirection,
    this.lookingFor,
    this.educationLevel,
    this.lifestyle = const {},
    this.aboutYou = const {},
    this.activityStatus,
    this.wantChildren,
    this.school,
    this.heightCm,
    this.jobTitle,
    this.jobCompany,
    this.cityName,
    this.languages = const [],
    this.superLikedMe = false,
    this.detailsLoaded = true,
  });

  factory DiscoveryCandidate.fromJson(Map<String, dynamic> json) =>
      DiscoveryCandidate(
        publicId: json['public_id'],
        name: json['name'],
        age: json['age'],
        bio: json['bio'] ?? '',
        interests: List<String>.from(json['interests'] ?? []),
        prompts: (json['prompts'] as List? ?? [])
            .map((e) => PromptAnswer.fromJson(e))
            .toList(),
        photos: _photosFrom(json['photos']),
        distanceKm: json['distance_km'] == null
            ? null
            : (json['distance_km'] as num).toDouble(),
        version: (json['version'] as num?)?.toInt() ?? 0,
        previousDirection: json['previous_direction'],
        lookingFor: _nullIfEmpty(json['looking_for'] as String?),
        educationLevel: _nullIfEmpty(json['education_level'] as String?),
        lifestyle: _stringMap(json['lifestyle']),
        aboutYou: _stringMap(json['about_you']),
        activityStatus: _activityFrom(json),
        wantChildren: _nullIfEmpty(json['want_children'] as String?),
        school: _nullIfEmpty(json['school'] as String?),
        heightCm: (json['height_cm'] as num?)?.toInt(),
        jobTitle: _nullIfEmpty(json['job_title'] as String?),
        jobCompany: _nullIfEmpty(json['job_company'] as String?),
        cityName: _nullIfEmpty(json['city_name'] as String?),
        languages: List<String>.from(json['languages'] ?? const []),
        superLikedMe: json['super_liked_me'] ?? false,
        detailsLoaded: json['lean'] != true,
      );

  // کارتِ سبکِ سرور عکس‌ها رو فقط به‌صورتِ آدرس (String) می‌فرسته؛ کارتِ کامل Map.
  static List<Photo> _photosFrom(dynamic raw) {
    final list = raw as List? ?? const [];
    final out = <Photo>[];
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is String) {
        out.add(Photo(id: '', url: e, position: i));
      } else {
        out.add(Photo.fromJson(e as Map<String, dynamic>));
      }
    }
    return out;
  }

  /// فقط «محتوای کارت» (چیزی که با version عوض می‌شه) — برای CardCache. فیلدهای وابسته
  /// به بیننده (previous_direction، super_liked_me، فاصله) عمداً نیستن؛ اون‌ها تو
  /// صف/لیستِ هر صفحه نگه داشته می‌شن، نه تو کش.
  Map<String, dynamic> toCacheJson() => {
        'public_id': publicId,
        'name': name,
        'age': age,
        'bio': bio,
        'interests': interests,
        'photos': [for (final p in photos) p.url],
        'version': version,
        // جزئیات (همون‌هایی که با زدنِ فلش میان) فقط وقتی تو کشن که واقعاً گرفته شده باشن؛
        // نسخه‌ی جزئیات همیشه با version کارت یکیه.
        'lean': !detailsLoaded,
        if (detailsLoaded) ...{
          'prompts': [for (final p in prompts) p.toJson()],
          'looking_for': lookingFor,
          'education_level': educationLevel,
          'school': school,
          'lifestyle': lifestyle,
          'about_you': aboutYou,
          'want_children': wantChildren,
          'height_cm': heightCm,
          'job_title': jobTitle,
          'job_company': jobCompany,
          'city_name': cityName,
          'languages': languages,
        },
      };

  /// کپیِ کامل (با همه‌ی جزئیات) با superLikedMe=true — برای صفِ Discovery.
  DiscoveryCandidate withSuperLiked() => DiscoveryCandidate(
        publicId: publicId, name: name, age: age, bio: bio, interests: interests,
        prompts: prompts, photos: photos, distanceKm: distanceKm, version: version,
        previousDirection: previousDirection, lookingFor: lookingFor,
        educationLevel: educationLevel, lifestyle: lifestyle, aboutYou: aboutYou,
        activityStatus: activityStatus, wantChildren: wantChildren, school: school,
        heightCm: heightCm, jobTitle: jobTitle, jobCompany: jobCompany, cityName: cityName,
        languages: languages, superLikedMe: true, detailsLoaded: detailsLoaded,
      );

  // اگه بک‌اند مستقیم `activity_status` بفرسته همون رو می‌گیریم؛ وگرنه از
  // `created_at` و `last_active_at` (ISO 8601) حسابش می‌کنیم.
  static String? _activityFrom(Map<String, dynamic> json) {
    final explicit = json['activity_status'];
    if (explicit is String && explicit.isNotEmpty) return explicit;

    final created = DateTime.tryParse('${json['created_at'] ?? ''}');
    final active = DateTime.tryParse('${json['last_active_at'] ?? ''}');
    final now = DateTime.now().toUtc();

    if (created != null && now.difference(created.toUtc()).inDays < 7) {
      return 'new';
    }
    if (active != null) {
      final diff = now.difference(active.toUtc());
      if (diff.inMinutes < 5) return 'active';
      if (diff.inHours < 24) return 'recent';
    }
    return null;
  }
}


/// بک‌اند برای فیلدِ پر نشده رشته‌ی خالی می‌فرسته؛ تو اپ «خالی» باید null باشه
/// (وگرنه شمارنده‌ی Basics و هشدار «پروفایلت رو کامل کن» اشتباه حساب می‌شن).
String? _nullIfEmpty(String? v) => (v == null || v.trim().isEmpty) ? null : v;
