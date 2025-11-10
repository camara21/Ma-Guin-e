plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter doit venir après Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ requis pour Firebase (google-services.json)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.soneya.ma_guinee"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Java 17 + desugaring (requis par flutter_local_notifications)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.soneya.ma_guinee"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // (Optionnel mais accélère sur ton Samsung ARM64)
        // ndk { abiFilters += listOf("arm64-v8a") }
    }

    buildTypes {
        release {
            // signature debug pour tester rapidement en --release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring >= 2.1.4 exigé par flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Si l'accessor n'est pas reconnu, utilise la forme:
    // add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.5")
}
