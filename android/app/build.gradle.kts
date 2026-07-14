import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Mapping/native-symbol uploads are release-publishing side effects, not APK
// compilation requirements. Keep local and device builds deterministic and
// opt in from the store/CI pipeline with -PuploadCrashlyticsSymbols=true.
val uploadCrashlyticsSymbols = providers.gradleProperty(
    "uploadCrashlyticsSymbols",
).map(String::toBoolean).orElse(false)

android {
    namespace = "com.silarah.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.silarah.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            configure<CrashlyticsExtension> {
                mappingFileUploadEnabled = uploadCrashlyticsSymbols.get()
                nativeSymbolUploadEnabled = uploadCrashlyticsSymbols.get()
            }
        }
    }
}

flutter {
    source = "../.."
}
