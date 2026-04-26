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

// ─────────────────────────────────────────────────────────────────────
// Patch third-party Flutter plugins that ship with stale Android config
// (missing namespace, JVM target 1.8 vs Kotlin's default of 21, etc.).
// Required for plugins like `flutter_jailbreak_detection 1.10.0` to
// build under AGP 8 + Kotlin 2.x without forking the package.
//
// IMPORTANT: must register `afterEvaluate` BEFORE the `evaluationDependsOn`
// block below, otherwise some subprojects are already evaluated and Gradle
// throws "Cannot run Project.afterEvaluate when the project is already
// evaluated".
// ─────────────────────────────────────────────────────────────────────
subprojects {
    afterEvaluate {
        // 1) Inject a namespace where the plugin author forgot one
        //    (AGP 8 requires `android.namespace`) and align Java target.
        plugins.withId("com.android.library") {
            extensions.configure(com.android.build.gradle.LibraryExtension::class.java) {
                if (namespace.isNullOrBlank()) {
                    namespace = "patched.${project.name.replace(Regex("[^A-Za-z0-9_]"), "_")}"
                }
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        // 2) Force every Kotlin compile task to target JVM 17 so it
        //    matches the Java compile target above (otherwise Gradle
        //    throws "Inconsistent JVM Target Compatibility").
        //    Uses the modern Kotlin 2.x `compilerOptions` DSL.
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
            .configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
