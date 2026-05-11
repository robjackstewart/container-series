use serde::{Deserialize, Serialize};
use spin_sdk::http::{IntoResponse, Request, Response};
use spin_sdk::http_component;

#[derive(Serialize, Clone)]
struct Item {
    id: u32,
    name: String,
}

#[derive(Deserialize)]
struct CreateItemRequest {
    name: String,
}

// Spin executes this handler per request inside a Wasm sandbox.
// There is no shared in-memory state between invocations unless you use
// an external state system such as Spin variables, key/value stores, or databases.
#[http_component]
fn handle_request(req: Request) -> impl IntoResponse {
    match (req.method().as_str(), req.uri().path()) {
        ("GET", "/") => text_response(
            200,
            "Welcome to the Spin Wasm demo! Runtime: wasm32-wasi via Fermyon Spin. Each request runs in a sandboxed, stateless WebAssembly component.",
        ),
        ("GET", "/health") => json_response(
            200,
            &serde_json::json!({
                "status": "healthy",
                "runtime": "wasm"
            }),
        ),
        ("GET", "/items") => json_response(200, &base_items()),
        ("POST", "/items") => handle_create_item(req),
        _ => text_response(404, "Not Found"),
    }
}

fn handle_create_item(req: Request) -> Response {
    // In a traditional server we might append to a global list.
    // In this Wasm example the list is reconstructed every request,
    // so the response shows the new item without persisting it.
    let body = String::from_utf8_lossy(req.body().as_ref()).trim().to_owned();

    let requested_name = if body.is_empty() {
        "Unnamed item".to_owned()
    } else {
        serde_json::from_str::<CreateItemRequest>(&body)
            .map(|payload| payload.name)
            .unwrap_or(body)
    };

    let mut items = base_items();
    items.push(Item {
        id: items.len() as u32 + 1,
        name: requested_name,
    });

    json_response(
        201,
        &serde_json::json!({
            "message": "Item accepted for this request only. Wasm handlers are stateless unless external storage is used.",
            "items": items
        }),
    )
}

fn base_items() -> Vec<Item> {
    vec![
        Item {
            id: 1,
            name: "Wasm module".to_owned(),
        },
        Item {
            id: 2,
            name: "Spin HTTP trigger".to_owned(),
        },
        Item {
            id: 3,
            name: "WASI sandbox".to_owned(),
        },
    ]
}

fn text_response(status: u16, body: &str) -> Response {
    Response::builder()
        .status(status)
        .header("content-type", "text/plain; charset=utf-8")
        .body(body.into())
        .unwrap()
}

fn json_response<T: Serialize>(status: u16, payload: &T) -> Response {
    Response::builder()
        .status(status)
        .header("content-type", "application/json")
        .body(serde_json::to_vec(payload).unwrap().into())
        .unwrap()
}
