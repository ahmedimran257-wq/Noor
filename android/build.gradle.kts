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

// nsfw_detect 2.6.4 declares flutter_embedding_debug:+ even for release.
// Flutter already injects the correct mode-specific, engine-pinned embedding.
subprojects {
    if (name == "nsfw_detect") {
        configurations.configureEach {
            withDependencies {
                removeIf {
                    it.group == "io.flutter" &&
                        it.name == "flutter_embedding_debug" &&
                        it.version == "+"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
