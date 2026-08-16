// Ce fichier est volontairement versionne, comme AndroidManifest.xml :
// `flutter create` (lance par .github/workflows/build.yml) genere le reste du
// dossier android/ mais ne remplace pas un fichier deja present.
//
// Il porte deux reglages que le gabarit par defaut ne contient pas et sans
// lesquels les rappels ne fonctionnent pas en build release :
//   - le desugaring, requis par flutter_local_notifications ;
//   - les regles ProGuard/R8, sans lesquelles Gson perd les TypeToken
//     generiques et zonedSchedule() echoue avec « Missing type parameter. ».

import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature de release.
//
// android/key.properties n'est JAMAIS versionne : il est ecrit au moment du
// build a partir des GitHub Secrets (voir .github/workflows/build.yml), ou
// cree a la main pour un build local.
//
// Sans lui, on retombe sur la cle de debug. C'etait le comportement du
// gabarit Flutter, et il est piegeux : sur un runner CI, cette cle est
// regeneree a chaque execution, donc chaque APK porte une signature
// differente. Android refuse alors la mise a jour (« Application non
// installée ») et impose une desinstallation, qui detruit les donnees.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

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

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                // Chemin relatif a android/app/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Cle de release des qu'elle est disponible. Le repli sur la cle
            // de debug ne sert qu'aux builds locaux sans key.properties ; en
            // CI, l'absence de keystore fait echouer le build plus bas,
            // plutot que de produire un APK a la signature instable.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

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
