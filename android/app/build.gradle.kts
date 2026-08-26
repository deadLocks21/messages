plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.dtfh.messages"
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
        applicationId = "fr.dtfh.messages"
        // RoleManager (rôle SMS par défaut) exige 29 ; en dessous on retombe sur
        // l'intent ACTION_CHANGE_DEFAULT, d'où un minSdk qui reste bas.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // NotificationCompat + registerReceiver(RECEIVER_NOT_EXPORTED) + vérification
    // des permissions : utilisés par le pont SMS.
    implementation("androidx.core:core-ktx:1.13.1")

    // Orientation EXIF des photos. Ré-encoder une image sans la lire renverrait
    // les portraits couchés : `BitmapFactory` ignore l'orientation, la caméra
    // l'écrit pourtant dans les métadonnées plutôt que dans les pixels.
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}

flutter {
    source = "../.."
}
