package com.example.routes

import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get

fun Route.healthRoutes() {
    get("/health") {
        call.respond(
            mapOf(
                "status" to "healthy",
                "version" to (System.getenv("APP_VERSION") ?: "unknown")
            )
        )
    }
    get("/ready") {
        call.respond(mapOf("status" to "ready"))
    }
}
