use actix_web::{web, HttpResponse, Responder};
use uuid::Uuid;
use chrono::Utc;
use crate::AppState;
use crate::models::{Todo, CreateTodoRequest, UpdateTodoRequest};

pub async fn health() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({"status": "healthy", "service": "rust-todo-api"}))
}

pub async fn info() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({
        "app": "Rust Todo API",
        "version": std::env::var("APP_VERSION").unwrap_or_else(|_| "unknown".to_string()),
        "environment": std::env::var("ENVIRONMENT").unwrap_or_else(|_| "development".to_string()),
        "runtime": "Rust + Actix-web"
    }))
}

pub async fn get_todos(data: web::Data<AppState>) -> impl Responder {
    let todos = data.todos.lock().unwrap();
    HttpResponse::Ok().json(&*todos)
}

pub async fn create_todo(data: web::Data<AppState>, body: web::Json<CreateTodoRequest>) -> impl Responder {
    let mut todos = data.todos.lock().unwrap();
    let todo = Todo {
        id: Uuid::new_v4().to_string(),
        title: body.title.clone(),
        description: body.description.clone(),
        completed: false,
        created_at: Utc::now().to_rfc3339(),
    };
    todos.push(todo.clone());
    HttpResponse::Created().json(todo)
}

pub async fn get_todo(data: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let todos = data.todos.lock().unwrap();
    let id = path.into_inner();
    match todos.iter().find(|t| t.id == id) {
        Some(todo) => HttpResponse::Ok().json(todo),
        None => HttpResponse::NotFound().json(serde_json::json!({"error": "Todo not found"})),
    }
}

pub async fn update_todo(data: web::Data<AppState>, path: web::Path<String>, body: web::Json<UpdateTodoRequest>) -> impl Responder {
    let mut todos = data.todos.lock().unwrap();
    let id = path.into_inner();
    match todos.iter_mut().find(|t| t.id == id) {
        Some(todo) => {
            if let Some(title) = &body.title { todo.title = title.clone(); }
            if let Some(desc) = &body.description { todo.description = Some(desc.clone()); }
            if let Some(completed) = body.completed { todo.completed = completed; }
            HttpResponse::Ok().json(todo.clone())
        },
        None => HttpResponse::NotFound().json(serde_json::json!({"error": "Todo not found"})),
    }
}

pub async fn delete_todo(data: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let mut todos = data.todos.lock().unwrap();
    let id = path.into_inner();
    let len_before = todos.len();
    todos.retain(|t| t.id != id);
    if todos.len() < len_before {
        HttpResponse::NoContent().finish()
    } else {
        HttpResponse::NotFound().json(serde_json::json!({"error": "Todo not found"}))
    }
}