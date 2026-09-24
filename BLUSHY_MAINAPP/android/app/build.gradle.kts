import java.util.Properties

// Release signing is configured through android/key.properties, which is not
// committed. When it is absent the build falls back to the debug key so local
// release builds keep working -- but such an APK cannot be published.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.blushy.blushy_love_app"
    compileSdk = 36

    // Set explicitly, because unset does not mean "no opinion": AGP falls back
    // to its own default (27.0.12077973) while the `jni` plugin -- pulled in
    // transitively -- declares `ndkVersion flutter.ndkVersion`. The two
    // disagreeing is what the NDK warning was about.
    //
    // Taken from the same source `jni` takes it from rather than written out,
    // so the next Flutter upgrade moves both together instead of leaving this
    // pinned to a version nothing else is using.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.blushy.blushy_love_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Debug-signed: runnable, but Play Store will reject it.
                signingConfigs.getByName("debug")
            }
            // Turn on R8: it shrinks unused code, optimizes what's left, and
            // (with shrinkResources) drops unreferenced resources -- the
            // "improve performance with R8 optimization" advice from Play
            // Console. proguard-rules.pro keeps the reflection/JNI classes
            // Flutter and the plugins reach so shrinking stays safe. Because
            // R8 stripping only shows up at runtime, the release APK must be
            // smoke-tested on a device before publishing.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
