import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class IdOcrResult {
  const IdOcrResult({
    required this.rawText,
    this.fullName,
    this.dateOfBirth,
  });

  final String rawText;
  final String? fullName;
  final DateTime? dateOfBirth;

  int? get age => dateOfBirth == null ? null : IdOcrService.ageOn(dateOfBirth!);
  bool get isAdult => age != null && age! >= 18;
}

/// On-device ID OCR. No document content is sent to an OCR API.
class IdOcrService {
  IdOcrService._();
  static final instance = IdOcrService._();

  Future<IdOcrResult> extract(File idPhoto) async {
    final input = InputImage.fromFile(idPhoto);
    final outputs = <String>[];
    for (final script in TextRecognitionScript.values) {
      final recognizer = TextRecognizer(script: script);
      try {
        final text = (await recognizer.processImage(input)).text.trim();
        if (text.isNotEmpty && !outputs.contains(text)) outputs.add(text);
      } finally {
        await recognizer.close();
      }
    }
    final rawText = outputs.join('\n');
    return IdOcrResult(
      rawText: rawText,
      fullName: extractNameFromText(rawText),
      dateOfBirth: extractDobFromText(rawText),
    );
  }

  /// Ported parsing behavior for common identity-document date formats.
  static DateTime? extractDobFromText(String text) {
    final normalized = text.replaceAll('\r', '\n');
    final labeled = RegExp(
      r'(?:date\s*of\s*birth|dob|birth\s*date|born|d\.?o\.?b\.?)\s*[:\-]?\s*'
      r'(\d{1,4}[\/.\-]\d{1,2}[\/.\-]\d{1,4})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final candidates = <String>[
      if (labeled != null) labeled.group(1)!,
      ...RegExp(r'\b\d{1,4}[\/.\-]\d{1,2}[\/.\-]\d{1,4}\b')
          .allMatches(normalized)
          .map((match) => match.group(0)!),
    ];
    for (final candidate in candidates) {
      final parsed = _parseDate(candidate);
      if (parsed != null && ageOn(parsed) <= 120) return parsed;
    }
    return null;
  }

  static String? extractNameFromText(String text) {
    final labeled = RegExp(
      r"(?:full\s*name|name)\s*[:\-]\s*([A-Za-z][A-Za-z .'-]{1,80})",
      caseSensitive: false,
    ).firstMatch(text);
    final value = labeled?.group(1)?.trim();
    if (value == null || value.length < 2) return null;
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  static int ageOn(DateTime dob, {DateTime? onDate}) {
    final today = onDate ?? DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  static DateTime? _parseDate(String value) {
    final pieces = value.split(RegExp(r'[/.\-]'));
    if (pieces.length != 3) return null;
    final first = int.tryParse(pieces[0]);
    final second = int.tryParse(pieces[1]);
    final third = int.tryParse(pieces[2]);
    if (first == null || second == null || third == null) return null;

    final year = pieces[0].length == 4 ? first : third;
    final month = pieces[0].length == 4 ? second : second;
    final day = pieces[0].length == 4 ? third : first;
    if (year < 1900 || year > DateTime.now().year || month < 1 || month > 12) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }
}
