import org.gradle.api.tasks.Delete
import java.io.File

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Plugin Firebase Google Services (obligatoire pour FCM)
        classpath("com.google.gms:google-services:4.3.15")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// IMPORTANT : pour que Flutter trouve bien l'APK dans ../build
// (équivalent de: rootProject.buildDir = '../build' en Groovy)
rootProject.buildDir = File("../build")

// Même logique que le fichier Groovy d’origine, mais en Kotlin
subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
