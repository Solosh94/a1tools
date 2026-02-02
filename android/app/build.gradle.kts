import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing props from key.properties (if present)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.a1chimney.a1tools"
    compileSdk = flutter.compileSdkVersion
    // NDK for native library compilation
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Set your unique app ID
        applicationId = "com.a1chimney.a1tools"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Support 16 KB page sizes (required for Android 15+)
    packaging {
        jniLibs {
            useLegacyPackaging = false
            // Ensure proper alignment for 16KB pages
            keepDebugSymbols += "**/*.so"
        }
    }

    // Experimental flags for 16KB page alignment
    @Suppress("UnstableApiUsage")
    experimentalProperties["android.experimental.enableNewResourceShrinker"] = true

    signingConfigs {
        // Create release config only if key.properties exists
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                val storePath = keystoreProperties["storeFile"] as String?
                if (!storePath.isNullOrBlank()) {
                    storeFile = file(storePath)
                }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Use real signing if configured, otherwise fall back to debug so you can still build.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Enable R8 for code shrinking and obfuscation
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Skip debug symbols to avoid stripping issues
            ndk {
                debugSymbolLevel = "NONE"
            }
        }
        debug {
            // optional: keep defaults
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // AndroidX Core for WindowCompat (edge-to-edge support on Android 15+)
    implementation("androidx.core:core-ktx:1.15.0")
}