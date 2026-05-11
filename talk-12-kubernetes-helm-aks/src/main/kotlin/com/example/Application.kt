package com.example

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import com.example.routes.healthRoutes
import com.example.routes.itemRoutes
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.calllogging.CallLogging
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import io.ktor.server.plugins.cors.routing.CORS
import io.ktor.server.plugins.statuspages.StatusPages
import io.ktor.server.response.respond
import io.ktor.server.routing.routing
import org.slf4j.LoggerFactory

fun main() {
    configureLogback()

    val port = System.getenv("PORT")?.toIntOrNull() ?: 8080
    val logger = LoggerFactory.getLogger("com.example.Application")

    logger.info("Starting Talk 12 API on port {}", port)

    embeddedServer(Netty, port = port, module = Application::module)
        .start(wait = true)
}

fun Application.module() {
    install(CallLogging)
    install(ContentNegotiation) {
        json()
    }
    install(StatusPages) {
        exception<Throwable> { call, cause ->
            call.respond(
                HttpStatusCode.InternalServerError,
                mapOf("error" to "Internal server error", "message" to (cause.message ?: "unknown"))
            )
        }
    }
    install(CORS) {
        anyHost()
        allowMethod(HttpMethod.Get)
        allowMethod(HttpMethod.Post)
        allowMethod(HttpMethod.Delete)
        allowHeader(HttpHeaders.ContentType)
    }

    routing {
        healthRoutes()
        itemRoutes()
    }
}

private fun configureLogback() {
    val rootLogger = LoggerFactory.getLogger(org.slf4j.Logger.ROOT_LOGGER_NAME) as Logger
    val levelName = System.getenv("LOG_LEVEL")?.uppercase() ?: "INFO"
    rootLogger.level = Level.toLevel(levelName, Level.INFO)
}
