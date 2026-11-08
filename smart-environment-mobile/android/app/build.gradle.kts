plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.beresin_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // ✅ Kotlin DSL harus pakai ini, bukan coreLibraryDesugaringEnabled
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.beresin_app" // ✅ cocok sama userAgentPackageName di TileLayer
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // sementara pake debug signing, nanti bisa ganti release keystore
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ✅ ini wajib untuk desugaring (Java 8+ API support)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

    // Flutter dependencies auto-inject lewat plugin flutter-gradle
}

flutter {
    source = "../.."
}
