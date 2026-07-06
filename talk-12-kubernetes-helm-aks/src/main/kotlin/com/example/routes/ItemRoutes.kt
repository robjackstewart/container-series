package com.example.routes

import com.example.models.Item
import com.example.models.ItemCreate
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.call
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.delete
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route

fun Route.itemRoutes() {
    val items = mutableListOf(
        Item(1, "Widget", "A fine widget"),
        Item(2, "Gadget", "A useful gadget")
    )

    route("/items") {
        get {
            call.respond(items)
        }

        post {
            val item = call.receive<ItemCreate>()
            items.add(Item(items.size + 1, item.name, item.description))
            call.respond(HttpStatusCode.Created, items.last())
        }

        get("/{id}") {
            val id = call.parameters["id"]?.toIntOrNull()
            val item = items.find { it.id == id }

            if (item != null) {
                call.respond(item)
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "Not found"))
            }
        }

        delete("/{id}") {
            val id = call.parameters["id"]?.toIntOrNull()
            val removed = items.removeIf { it.id == id }

            if (removed) {
                call.response.status(HttpStatusCode.NoContent)
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf("error" to "Not found"))
            }
        }
    }
}
