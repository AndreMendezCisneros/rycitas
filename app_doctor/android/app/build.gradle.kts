import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase solo se activa cuando existe su archivo. Así la app compila antes de crear el proyecto de Firebase:
// funciona igual, solo que sin push. Colocar en android/app/src/{dev,prod}/google-services.json.
val hayFirebase = listOf("src/dev", "src/prod").any { file("$it/google-services.json").exists() }
if (hayFirebase) {
    apply(plugin = "com.google.gms.google-services")
}

// Firma de publicación: android/key.properties (no se sube al repositorio). Sin él, firma de depuración.
val propiedadesFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}

android {
    namespace = "pe.rycitas.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "pe.rycitas.app"
        minSdk = 26 // Android 8.0 (RNF-11)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (propiedadesFirma.containsKey("storeFile")) {
            create("publicacion") {
                storeFile = rootProject.file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
            }
        }
    }

    flavorDimensions += "entorno"
    productFlavors {
        create("dev") {
            dimension = "entorno"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "RyCitas dev")
        }
        create("prod") {
            dimension = "entorno"
            resValue("string", "app_name", "RyCitas")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("publicacion") ?: signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
