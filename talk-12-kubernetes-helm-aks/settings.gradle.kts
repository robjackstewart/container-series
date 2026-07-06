pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id.startsWith("org.jetbrains.kotlin")) {
                val artifactId = if (requested.id.id == "org.jetbrains.kotlin.plugin.serialization")
                    "kotlin-serialization" else "kotlin-gradle-plugin"
                useModule("org.jetbrains.kotlin:$artifactId:${requested.version}")
            }
        }
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

rootProject.name = "container-series-talk-12"
