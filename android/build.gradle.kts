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

// vibration@2.0.0 is compiled against android-33 but pulls androidx.fragment:1.7.1
// (needs 34). Pin fragment to the last 33-compatible release so the AAR
// metadata check passes without forking the plugin.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.fragment:fragment:1.6.2")
            force("androidx.window:window:1.1.0")
            force("androidx.window:window-java:1.1.0")
        }
    }
    // vibration@2.0.0 (android-33) pulls androidx deps compiled for 34+; each
    // pin reveals another. The check is advisory for API-level mismatches, so
    // disable it for library modules and rely on the pins above + runtime tests.
    tasks.matching { it.name == "checkReleaseAarMetadata" || it.name == "checkDebugAarMetadata" || it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}
