import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets de signature, jamais versionnés : voir android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

// Une build de distribution doit être signée avec la clé de production. La clé
// de débogage est publique et connue : n'importe qui pourrait signer une
// version modifiée de l'application avec la même identité, et un téléphone
// l'accepterait comme une mise à jour. Le build s'arrête donc, plutôt que de
// produire un APK trompeusement complet derrière un avertissement noyé dans la
// sortie. Les builds de débogage ne sont pas concernées.
val buildsRelease = gradle.startParameter.taskNames.any { it.contains("Release") }
if (buildsRelease && !hasReleaseKeystore) {
    throw GradleException(
        "android/key.properties absent : impossible de signer une build de " +
            "distribution. Voir android/key.properties.example."
    )
}

android {
    namespace = "com.example.my_clinic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.my_clinic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signature de production. Son absence a déjà arrêté le build
            // ci-dessus ; la clé de débogage ne sert de repli que pour les
            // tâches qui ne produisent pas de livrable (analyse, sync de
            // l'IDE), où la configuration est tout de même évaluée.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
