import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// The signing key lives outside the repository, beside the member app's key.
// Only release builds need it; debug builds use the local debug key.
val signingFile = File(
    System.getProperty("user.home"),
    ".silarah/release-signing/admin-key.properties",
)
val signing = Properties().apply {
    if (signingFile.exists()) FileInputStream(signingFile).use { load(it) }
}

android {
    namespace = "com.silarah.admin"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.silarah.admin"
        minSdk = 26
        targetSdk = 36
        versionCode = 4
        versionName = "1.0.3"
    }

    signingConfigs {
        create("release") {
            if (signingFile.exists()) {
                storeFile = File(signingFile.parentFile, signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
