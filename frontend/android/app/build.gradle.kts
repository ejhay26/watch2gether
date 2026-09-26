plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.watch2gether.watch2gether"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.watch2gether.watch2gether"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode ?: 6
        versionName = flutter.versionName ?: "1.0.6"
    }

    val customKeyFile = when {
        file("newkey").exists() -> file("newkey")
        file("${rootDir}/newkey").exists() -> file("${rootDir}/newkey")
        file("C:/Users/Administrator/Documents/git/newkey").exists() -> file("C:/Users/Administrator/Documents/git/newkey")
        else -> null
    }

    signingConfigs {
        if (customKeyFile != null && customKeyFile.exists()) {
            create("release") {
                keyAlias = "key1"
                keyPassword = "12345678"
                storeFile = customKeyFile
                storePassword = "12345678"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (customKeyFile != null && customKeyFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
