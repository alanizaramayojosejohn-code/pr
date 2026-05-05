allprojects {
    repositories {
        google()
        mavenCentral()
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

// Workaround: Gradle 8.x transform cache ATOMIC_MOVE race condition on Windows NTFS.
// Multiple transform workers race to commit the same hash directory; all but the first fail.
// Disabling LintModel + ArtProfile/BaselineProfile tasks across all projects prevents the
// race entirely — lint analysis and startup profiles are not required for a functional APK.
gradle.projectsEvaluated {
    allprojects {
        tasks.matching { task ->
            task.name.contains("LintModel", ignoreCase = true) ||
            task.name.contains("lintVital", ignoreCase = false) ||
            task.name.contains("ArtProfile", ignoreCase = true) ||
            task.name.contains("BaselineProfile", ignoreCase = true)
        }.configureEach { enabled = false }
    }
}
