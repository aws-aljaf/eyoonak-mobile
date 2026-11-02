import java.util.Base64

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val eyoonakReleaseMode = System.getenv("EYOONAK_RELEASE_MODE")
val eyoonakProduction = if (eyoonakReleaseMode != null) eyoonakReleaseMode == "production"
    else providers.gradleProperty("eyoonakProduction").orNull == "true"
val eyoonakReview = if (eyoonakReleaseMode != null) eyoonakReleaseMode == "review"
    else providers.gradleProperty("eyoonakReviewSigning").orNull == "true"
val eyoonakStore = System.getenv("EYOONAK_SIGNING_STORE")
val eyoonakPassword = System.getenv("EYOONAK_SIGNING_PASSWORD")
val eyoonakAlias = System.getenv("EYOONAK_SIGNING_ALIAS") ?: "eyoonak-upload"

android {
    namespace = "com.example.fleet_saas_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (eyoonakProduction) "com.eyoonak.app" else "com.example.fleet_saas_driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!eyoonakStore.isNullOrBlank() && !eyoonakPassword.isNullOrBlank()) {
            create("eyoonakProduction") {
                storeFile = file(eyoonakStore)
                storePassword = eyoonakPassword
                keyAlias = eyoonakAlias
                keyPassword = eyoonakPassword
                storeType = "PKCS12"
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (eyoonakProduction) signingConfigs.findByName("eyoonakProduction")
                else if (eyoonakReview) signingConfigs.getByName("debug") else null
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}


// Review APKs keep their existing package/signature; production is an independent install.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release", ignoreCase = true) }) {
        if (eyoonakProduction == eyoonakReview) throw GradleException("Choose production or explicit review signing; debug fallback is disabled.")
        if (eyoonakProduction) {
            if (eyoonakStore.isNullOrBlank() || eyoonakPassword.isNullOrBlank() || !file(eyoonakStore).isFile)
                throw GradleException("Production upload keystore is required.")
            val defines = (project.findProperty("dart-defines") as String? ?: "").split(",").filter { it.isNotEmpty() }
                .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
            if (!defines.contains("API_BASE_URL=https://app.eyoonak.com/api/v1"))
                throw GradleException("Production must target the Eyoonak HTTPS API.")
        }
    }
}

