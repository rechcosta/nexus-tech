plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.edu.ifrs.osorio.nexus_tech"
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
        applicationId = "br.edu.ifrs.osorio.nexus_tech"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            if (keystorePath != null) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        // Builds de DEBUG apontam para o ambiente de teste
        // (nexus-tech-2025-dev) e por isso precisam de applicationId próprio.
        //
        // Motivo: o Google Cloud trata o par (applicationId + SHA-1 do
        // certificado) como GLOBALMENTE único. O par
        // `br.edu.ifrs.osorio.nexus_tech` + SHA-1 da keystore de debug já
        // pertence ao projeto de produção, então o projeto de teste não
        // conseguia criar o próprio cliente OAuth — e o login com Google
        // falhava com ApiException 10 (DEVELOPER_ERROR), sem mensagem útil.
        //
        // O sufixo desempata sem tocar em produção, e de quebra permite os
        // dois apps instalados no mesmo aparelho.
        // Ver docs/AMBIENTES.md.
        debug {
            applicationIdSuffix = ".dev"
            // Rótulo distinto na gaveta de apps — sem isto ficam dois ícones
            // idênticos e não há como saber qual aponta para qual ambiente.
            manifestPlaceholders["appLabel"] = "Nexus Tech DEV"
        }

        release {
            manifestPlaceholders["appLabel"] = "Nexus Tech"
            signingConfig = if (System.getenv("KEYSTORE_PATH") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}