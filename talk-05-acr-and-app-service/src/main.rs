use actix_web::{web, App, HttpServer, HttpResponse, middleware::Logger};
use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use uuid::Uuid;
use chrono::Utc;

mod models;
mod handlers;

use models::Todo;

pub struct AppState {
    pub todos: Mutex<Vec<Todo>>,
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));
    
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let port: u16 = port.parse().expect("PORT must be a number");
    
    log::info!("Starting server on port {}", port);
    log::info!("Environment: {}", std::env::var("ENVIRONMENT").unwrap_or_else(|_| "development".to_string()));
    log::info!("Version: {}", std::env::var("APP_VERSION").unwrap_or_else(|_| "unknown".to_string()));

    let data = web::Data::new(AppState {
        todos: Mutex::new(vec![
            Todo {
                id: Uuid::new_v4().to_string(),
                title: "Learn Rust".to_string(),
                description: Some("Build something great with Rust".to_string()),
                completed: false,
                created_at: Utc::now().to_rfc3339(),
            },
        ]),
    });

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .wrap(Logger::default())
            .route("/health", web::get().to(handlers::health))
            .route("/info", web::get().to(handlers::info))
            .route("/todos", web::get().to(handlers::get_todos))
            .route("/todos", web::post().to(handlers::create_todo))
            .route("/todos/{id}", web::get().to(handlers::get_todo))
            .route("/todos/{id}", web::put().to(handlers::update_todo))
            .route("/todos/{id}", web::delete().to(handlers::delete_todo))
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}