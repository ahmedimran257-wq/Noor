import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import java.util.Properties

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

val signingPropertiesPath = providers.environmentVariable(
    "SILARAH_SIGNING_PROPERTIES",
).orElse(
    providers.systemProperty("user.home").map {
        "$it/.silarah/release-signing/key.properties"
    },
)
val signingPropertiesFile = file(signingPropertiesPath.get())
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}
val isReleaseInvocation = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

fun requiredSigningProperty(name: String): String {
    val value = signingProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException(
            "Missing Android release signing property '$name' in " +
                signingPropertiesFile.absolutePath,
        )
    }
    return value
}

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
        applicationId = "com.silarah.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (signingPropertiesFile.exists()) {
                storeFile = file(requiredSigningProperty("storeFile"))
                storePassword = requiredSigningProperty("storePassword")
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
            } else if (isReleaseInvocation) {
                throw GradleException(
                    "Android release signing configuration is missing. Expected " +
                        signingPropertiesFile.absolutePath,
                )
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

tasks.register("verifyReleaseSigning") {
    group = "verification"
    description = "Fails when the production build is unsigned or uses the debug keystore."
    doLast {
        val release = android.signingConfigs.getByName("release")
        val debug = android.signingConfigs.getByName("debug")
        val releaseStore = release.storeFile?.canonicalFile
            ?: throw GradleException("Release keystore is not configured.")
        val debugStore = debug.storeFile?.canonicalFile
        if (!releaseStore.isFile) {
            throw GradleException("Release keystore does not exist: $releaseStore")
        }
        if (debugStore != null && releaseStore == debugStore) {
            throw GradleException("Production artifacts must never use the debug keystore.")
        }
        if (release.keyAlias.isNullOrBlank()) {
            throw GradleException("Release key alias is not configured.")
        }
    }
}

// Flutter integration tests can leave a legacy source-tree registrant that
// references the dev-only integration_test plugin. Modern Flutter builds own
// plugin registration, so remove that ignored generated file before Android
// snapshots Java sources. This keeps direct local release builds as reliable
// as CI and the device-install script.
val removeDevOnlyGeneratedPluginRegistrant =
    tasks.register<Delete>("removeDevOnlyGeneratedPluginRegistrant") {
        delete(
            layout.projectDirectory.file(
                "src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
            ),
        )
    }

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(removeDevOnlyGeneratedPluginRegistrant)
}

tasks.matching {
    it.name == "bundleRelease" || it.name == "assembleRelease"
}.configureEach {
    dependsOn("verifyReleaseSigning")
}

flutter {
    source = "../.."
}
