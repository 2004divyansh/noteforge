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
    if (project.name != "app") {
        afterEvaluate {
            val extension = project.extensions.findByName("android")
            if (extension != null) {
                for (m in extension.javaClass.methods) {
                    if (m.name in listOf("setCompileSdkVersion", "compileSdkVersion", "setCompileSdk") &&
                        m.parameterCount == 1 &&
                        m.parameterTypes[0] == Int::class.javaPrimitiveType) {
                        try {
                            m.invoke(extension, 36)
                        } catch (_: Exception) {}
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
