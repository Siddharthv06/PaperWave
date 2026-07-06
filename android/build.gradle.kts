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

fun getAndroidManifestPackage(proj: org.gradle.api.Project): String? {
    val manifestFile = proj.file("src/main/AndroidManifest.xml")
    if (manifestFile.exists()) {
        try {
            val contents = manifestFile.readText()
            val matcher = java.util.regex.Pattern.compile("package=\"([^\"]+)\"").matcher(contents)
            if (matcher.find()) {
                return matcher.group(1)
            }
        } catch (e: Exception) {
            // Ignore read errors
        }
    }
    return null
}

subprojects {
    if (project.name != "app") {
        // Set namespace early when the plugin is applied
        project.plugins.withId("com.android.library") {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                if (android.namespace.isNullOrEmpty()) {
                    val pkg = getAndroidManifestPackage(project)
                    android.namespace = pkg ?: "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                }
            }
        }
        project.plugins.withId("com.android.application") {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                if (android.namespace.isNullOrEmpty()) {
                    val pkg = getAndroidManifestPackage(project)
                    android.namespace = pkg ?: "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                }
            }
        }

        // Force compileSdkVersion late after build.gradle files are evaluated
        afterEvaluate {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                android.compileSdkVersion(36)
            }
        }
    }
}
