# google_mlkit_text_recognition supports optional script-specific artifacts.
# Silarah uses the bundled Latin recognizer, so references to recognizers that
# are deliberately not packaged may be ignored during R8 analysis.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ML Kit object detection's Flutter wrapper compiles optional support for
# Firebase-hosted custom models. Silarah only invokes its bundled default
# detector, and the obsolete firebase-iid module is intentionally excluded in
# android/build.gradle.kts to avoid a duplicate receiver with Firebase
# Messaging. This unreachable optional path is the only remaining reference.
-dontwarn com.google.firebase.iid.FirebaseInstanceId
