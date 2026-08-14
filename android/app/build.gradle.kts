// Ce fichier est volontairement versionne, comme AndroidManifest.xml :
// `flutter create` (lance par .github/workflows/build.yml) genere le reste du
// dossier android/ mais ne remplace pas un fichier deja present.
//
// Il porte deux reglages que le gabarit par defaut ne contient pas et sans
// lesquels les rappels ne fonctionnent pas en build release :
//   - le desugaring, requis par flutter_local_notifications ;
//   - les regles ProGuard/R8, sans lesquelles Gson perd les TypeToken
//     generiques et zonedSchedule() echoue avec « Missing type parameter. ».

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.memotack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.memotack"
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

            // R8 tourne sur cette build : sans les regles ci-dessous, il
            // supprime les signatures generiques dont Gson a besoin pour
            // (de)serialiser les notifications programmees.
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
