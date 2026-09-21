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
        if (lookingFor != null) 'looking_for': lookingFor,
        if (educationLevel != null) 'education_level': educationLevel,
        if (school != null && school!.isNotEmpty) 'school': school,
        'lifestyle': lifestyle,
        'about_you': aboutYou,
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
  final List<PromptAnswer> prompts;
  final List<Photo> photos;
  final String publicId;

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
        photos: (json['photos'] as List? ?? [])
            .map((e) => Photo.fromJson(e))
            .toList(),
        publicId: json['public_id'] ?? '',
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
  final String name;
  final int age;
  final String bio;
  final List<String> interests;
  final List<PromptAnswer> prompts;
  final List<Photo> photos;
  final double? distanceKm;
  final String? previousDirection; // null یعنی هیچ‌وقت swipe نشده

  // --- فیلدهای اختیاریِ کارت سبک تیندر ---
  // اگه بک‌اند (Go) این‌ها رو تو JSON بفرسته، روی کارت نشون داده می‌شن؛
  // اگه نفرسته، فقط همون بخش از کارت نمایش داده نمی‌شه (اپ خراب نمی‌شه).
  final String? lookingFor; // مثلاً "long_term"
  final String? educationLevel;
  final Map<String, String> lifestyle; // {"drinking": "sober", ...}
  final Map<String, String> aboutYou; // {"communication": "phone_caller", ...}
  final String? activityStatus; // 'active' | 'recent' | 'new' | null

  DiscoveryCandidate({
    required this.publicId,
    required this.name,
    required this.age,
    required this.bio,
    required this.interests,
    required this.prompts,
    required this.photos,
    required this.distanceKm,
    this.previousDirection,
    this.lookingFor,
    this.educationLevel,
    this.lifestyle = const {},
    this.aboutYou = const {},
    this.activityStatus,
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
        photos: (json['photos'] as List? ?? [])
            .map((e) => Photo.fromJson(e))
            .toList(),
        distanceKm: json['distance_km'] == null
            ? null
            : (json['distance_km'] as num).toDouble(),
        previousDirection: json['previous_direction'],
        lookingFor: json['looking_for'] as String?,
        educationLevel: json['education_level'] as String?,
        lifestyle: _stringMap(json['lifestyle']),
        aboutYou: _stringMap(json['about_you']),
        activityStatus: _activityFrom(json),
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
