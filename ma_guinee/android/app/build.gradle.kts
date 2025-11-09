plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter doit venir après Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
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

// Dépendance desugaring (>= 2.1.4 requis)
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Si ton Gradle n’a pas l'accessor ci-dessus, utilise cette forme :
    // add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.5")
}
