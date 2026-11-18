plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.doyadi.doyadi"
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
        applicationId = "com.doyadi.doyadi"
        // You can update the following values to match your application needs.
        // Support older Android versions starting from Android 5.0 (API 21) / Android 7 & 8
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    flavorDimensions += "app"
    productFlavors {
        create("oyuku") {
            dimension = "app"
            applicationId = "navilastro.oyuku"
            resValue("string", "app_name", "OyuKu")
        }
        create("doyadi") {
            dimension = "app"
            applicationId = "navilastro.doyadi"
            resValue("string", "app_name", "DoYaDi")
        }
        create("virplelev") {
            dimension = "app"
            applicationId = "navilastro.virplelev"
            resValue("string", "app_name", "VirPleLev")
        }
        create("sanrevye") {
            dimension = "app"
            applicationId = "navilastro.sanrevye"
            resValue("string", "app_name", "SanReVye")
        }
        create("admin") {
            dimension = "app"
            applicationId = "navilastro.admin"
            resValue("string", "app_name", "DoYaDi Boss")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
