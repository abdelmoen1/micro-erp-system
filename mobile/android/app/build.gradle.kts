import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the permanent Hisbah key (docs/mobile/ota-updates.md). CI writes
// android/key.properties and the keystore from repository secrets; both are git-ignored.
// Without key.properties a release build fails: it is never signed with the public debug key.
// Debug builds are unaffected.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) FileInputStream(keystorePropertiesFile).use { load(it) }
}

gradle.taskGraph.whenReady {
    val releaseTask = Regex("^(assemble|bundle|package)Release$")
    if (!keystorePropertiesFile.exists() && allTasks.any { it.project == project && releaseTask.matches(it.name) }) {
        throw GradleException(
            "Release signing is not configured: android/key.properties is missing. " +
                "Release builds are signed only with the Hisbah release key (see docs/mobile/ota-updates.md).",
        )
    }
}

android {
    namespace = "com.hisbah.smartshop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hisbah.smartshop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Phones only (64- and 32-bit ARM): x86_64 serves emulators and Chromebooks and added 30 MB.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    // Native libraries are compressed in the APK (about 49 MB down to 23 MB) and extracted on
    // install, as Flutter apps did before AGP 3.6. Halves the download from the website.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            // Shorebird's release build ignores ndk.abiFilters, so the x86 engines (12.7 MB, emulators
            // and Chromebooks only) are dropped here as well: no shop phone runs them.
            excludes += listOf("lib/x86_64/**", "lib/x86/**")
            // The sqlite3 package's build hook (pulled in by sqflite_common_ffi, a test-only
            // dependency) bundles its own SQLite; the app's sqflite uses Android's, so it is never loaded.
            excludes += "lib/**/libsqlite3.so"
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) signingConfig = signingConfigs.getByName("release")
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
