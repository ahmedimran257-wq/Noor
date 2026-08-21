// SILARAH — Background Compute / Isolate Parsers
// Offloads heavy JSON mapping/deserialization to background threads.
import '../models/discovery_profile.dart';
import '../cubits/chat/chat_state.dart';

/// Parse real discovery RPC rows into the profile view model.
List<DiscoveryProfile> parseProfilesInBackground(List<dynamic> list) {
  return list
      .map((row) => mapDbRowToDiscoveryProfile(row as Map<String, dynamic>))
      .toList();
}

/// Parse a single database profile row in the background.
DiscoveryProfile parseSingleProfileInBackground(Map<String, dynamic> row) {
  return mapDbRowToDiscoveryProfile(row);
}

/// Map a raw Supabase discovery row to the profile view model.
DiscoveryProfile mapDbRowToDiscoveryProfile(Map<String, dynamic> row) {
  final gender = row['gender'] as String?;
  final rawPhotoPath = row['photo_url'] as String?;
  final photoCount = (row['photo_count'] as num?)?.toInt() ?? 0;
  final photoPrivacy = row['photo_privacy'] as String?;
  final rawPhotoUrls = row['photo_urls'];

  return DiscoveryProfile(
    id: _requiredText(row, 'user_id'),
    firstName: _requiredText(row, 'first_name'),
    lastNameInitial: ((row['last_name_initial'] as String?) ?? '').isNotEmpty
        ? row['last_name_initial'] as String
        : (((row['last_name'] as String?) ?? '').isNotEmpty
            ? (row['last_name'] as String)[0]
            : ''),
    age: _requiredAge(row),
    cityName: _requiredText(row, 'city_name'),
    sect: _optionalText(row, 'sect')?.toUpperCase(),
    deenLevel: _optionalText(row, 'deen_level'),
    photoUrl: rawPhotoPath,
    photoUrls: rawPhotoUrls is Iterable
        ? rawPhotoUrls
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const [],
    photoCount: photoCount,
    isPhotoPrivate:
        photoPrivacy == 'mutual_only' || photoPrivacy == 'request_only',
    photoPrivacy: photoPrivacy ?? 'public',
    isVerified: (row['is_verified'] as bool?) ?? false,
    phoneVerified: (row['phone_verified'] as bool?) ?? false,
    guardianConnected: (row['guardian_connected'] as bool?) ?? false,
    isGuardianProfile: (row['guardian_managed'] as bool?) ?? false,
    establishedMember: (row['established_member'] as bool?) ?? false,
    occupation: _optionalText(row, 'profession'),
    education: _optionalText(row, 'education_level'),
    bio: _optionalText(row, 'bio'),
    languages: row['languages'] != null
        ? List<String>.from(row['languages'] as Iterable)
        : null,
    maritalStatus: (row['previously_married'] as String?) == 'no'
        ? 'Never Married'
        : _optionalText(row, 'previously_married'),
    familyType: _optionalText(row, 'family_type'),
    interests: row['interests'] != null
        ? List<String>.from(row['interests'] as Iterable)
        : null,
    partnerAgeMin: (row['preferred_age_min'] as num?)?.toInt(),
    partnerAgeMax: (row['preferred_age_max'] as num?)?.toInt(),
    partnerSect: row['sect_preference'] as String?,
    partnerDeenLevel: row['deen_preference'] as String?,
    partnerEducationMinRank: (row['min_education_rank'] as num?)?.toInt(),
    heightCm: (row['height_cm'] as num?)?.toInt(),
    complexion: (row['complexion'] as String?),
    motherTongue: (row['mother_tongue'] as String?),
    smokingHabit: (row['smoking_habit'] as String?),
    community: (row['community'] as String?),
    dietType: (row['diet_type'] as String?),
    livingExpectation: (row['living_expectation'] as String?),
    quranMemorization: (row['quran_memorization'] as String?),
    religiousEducation: (row['religious_education'] as String?),
    marriageTimeline: (row['marriage_timeline'] as String?),
    willingToRelocate: (row['willing_to_relocate'] as String?),
    gender: gender,
    hasChildren: (row['children_count'] as int? ?? 0) > 0,
    lastActiveAt: row['last_active_at'] != null
        ? DateTime.tryParse(row['last_active_at'] as String)
        : null,
    countryCode: row['country_code'] as String?,
    lastName: _optionalText(row, 'last_name'),
    blurhash: row['blurhash'] as String?,
    previousMatchAt: _optionalDateTime(row, 'previous_match_at'),
    previousMatchEndedAt: _optionalDateTime(row, 'previous_match_ended_at'),
    priorMatchCount: (row['prior_match_count'] as num?)?.toInt() ?? 0,
    rematchAvailableAt: _optionalDateTime(row, 'rematch_available_at'),
  );
}

DateTime? _optionalDateTime(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is DateTime) return value;
  return value == null ? null : DateTime.tryParse(value.toString());
}

String _requiredText(Map<String, dynamic> row, String key) {
  final value = _optionalText(row, key);
  if (value == null) {
    throw StateError('Supabase profile row is missing required field "$key".');
  }
  return value;
}

String? _optionalText(Map<String, dynamic> row, String key) {
  final raw = row[key];
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

int _requiredAge(Map<String, dynamic> row) {
  final age = (row['age'] as num?)?.toInt();
  if (age != null && age >= 18) return age;

  final dobText = _optionalText(row, 'date_of_birth');
  final dob = dobText == null ? null : DateTime.tryParse(dobText);
  if (dob != null) {
    final today = DateTime.now();
    var years = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      years--;
    }
    if (years >= 18) return years;
  }

  throw StateError(
    'Supabase profile row is missing a valid adult age/date_of_birth.',
  );
}

/// Input parameter structure for parsing message lists in background
class MessagesParseInput {
  const MessagesParseInput(
      {required this.messagesData, required this.myUserId});
  final List<dynamic> messagesData;
  final String myUserId;
}

/// Output result structure for parsing message lists in background
class MessagesParseResult {
  const MessagesParseResult(
      {required this.chatMessages, required this.unreadCount});
  final List<ChatMessage> chatMessages;
  final int unreadCount;
}

/// Parse message rows in background isolate.
MessagesParseResult parseMessagesInBackground(MessagesParseInput input) {
  final List<ChatMessage> chatMessages = [];
  int unreadCount = 0;

  for (var msg in input.messagesData) {
    final isMe = msg['sender_id'] == input.myUserId;
    final readAt = msg['read_at'];
    final isRead = readAt != null;
    if (!isMe && !isRead) {
      unreadCount++;
    }

    final translationsMap = msg['translations'] as Map<dynamic, dynamic>? ?? {};
    final translations = translationsMap.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );

    chatMessages.add(ChatMessage(
      id: msg['id'] as String,
      text: msg['content'] as String? ?? '',
      sentAt: DateTime.parse(msg['created_at'] as String).toLocal(),
      isMe: isMe,
      status: isRead
          ? MessageStatus.read
          : (isMe ? MessageStatus.sent : MessageStatus.delivered),
      translations: translations,
    ));
  }
  return MessagesParseResult(
      chatMessages: chatMessages, unreadCount: unreadCount);
}
