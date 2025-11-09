allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // ⚠️ Force la bonne version de desugar pour tous les modules
    configurations.all {
        resolutionStrategy {
            force("com.android.tools:desugar_jdk_libs:2.1.5")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
