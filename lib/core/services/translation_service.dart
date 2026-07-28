// lib/core/services/translation_service.dart
// ============================================================
// SILARAH — Translation Service (Muslima Feature)
//
// Communicates only with the Supabase translate-message Edge Function so
// private chat text never leaves the server-controlled boundary from Flutter.
// ============================================================

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  /// Translates one authorized chat message. The server fetches the message
  /// body after proving the caller belongs to its match.
  Future<String?> translate({
    required String messageId,
    required String targetLang,
  }) async {
    if (messageId.trim().isEmpty) return null;
    if (!SupabaseService.isInitialized) return null;

    try {
      final response = await SupabaseService.client.functions.invoke(
        'translate-message',
        body: {
          'message_id': messageId,
          'target_lang': targetLang,
        },
      );

      if (response.data is Map) {
        final data = response.data as Map;
        final translatedText = data['translated_text'] as String?;
        if (translatedText != null && translatedText.isNotEmpty) {
          return translatedText;
        }
      }
    } catch (e) {
      debugPrint('[TranslationService] Edge Function translation failed: $e');
    }
    return null;
  }
}
