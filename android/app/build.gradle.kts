plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // ४. ही ओळ सर्वात महत्त्वाची आहे, यामुळे Firebase चालू होईल
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ KTS मध्ये 'is' लावणं गरजेचं असतं
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // ✅ Warning घालवण्यासाठी सरळ "17" वापरलं आहे
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        
        minSdk = 26 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true 
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            pickFirsts.add("lib/x86/libtensorflowlite_c.so")
            pickFirsts.add("lib/x86_64/libtensorflowlite_c.so")
            pickFirsts.add("lib/armeabi-v7a/libtensorflowlite_c.so")
            pickFirsts.add("lib/arm64-v8a/libtensorflowlite_c.so")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ ही ओळ त्या 'Desugaring' एररला कायमचं घालवेल
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}