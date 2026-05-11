plugins {
    kotlin("jvm") version "2.0.21"
    kotlin("plugin.serialization") version "2.0.21"
    application
    id("com.github.johnrengelman.shadow") version "8.1.1"
}

group = "com.example"
version = "1.0.0"

val ktorVersion = "2.3.12"
val logbackVersion = "1.5.6"

repositories {
    mavenCentral()
}

dependencies {
    implementation("io.ktor:ktor-server-core-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-netty-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-content-negotiation-jvm:$ktorVersion")
    implementation("io.ktor:ktor-serialization-kotlinx-json-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-status-pages-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-cors-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-call-logging-jvm:$ktorVersion")
    implementation("ch.qos.logback:logback-classic:$logbackVersion")
}

kotlin {
    jvmToolchain(21)
}

application {
    mainClass.set("com.example.ApplicationKt")
}

tasks.shadowJar {
    archiveFileName.set("app.jar")
    mergeServiceFiles()
}

tasks.build {
    dependsOn(tasks.shadowJar)
}
