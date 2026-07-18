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

    // google_mlkit_object_detection 0.13.x includes ML Kit's optional
    // Firebase-hosted custom-model bridge. That bridge still declares the
    // retired firebase-iid artifact, whose receiver is already provided by
    // modern firebase-messaging. Keeping both makes release builds fail with
    // a duplicate FirebaseInstanceIdReceiver. Silarah uses the bundled ML Kit
    // detector only, so remove the obsolete transitive module everywhere.
    configurations.configureEach {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
