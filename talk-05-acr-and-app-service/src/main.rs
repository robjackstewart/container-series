mod handlers;
mod models;

use actix_web::{middleware::Logger, web, App, HttpServer};
use handlers::{
    create_todo, delete_todo, get_todo, get_todos, health, info, update_todo, AppState,
};
use std::{
    env,
    sync::{Arc, Mutex},
};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(env_logger::Env::default().default_filter_or("info"));

    let port = env::var("PORT")
        .ok()
        .and_then(|value| value.parse::<u16>().ok())
        .unwrap_or(8080);
    let app_version = env::var("APP_VERSION").unwrap_or_else(|_| "0.1.0".to_string());
    let environment = env::var("ENVIRONMENT").unwrap_or_else(|_| "development".to_string());

    let shared_state = web::Data::new(AppState {
        todos: Arc::new(Mutex::new(Vec::new())),
        app_version: app_version.clone(),
        environment: environment.clone(),
    });

    log::info!(
        "Starting todo API on 0.0.0.0:{port} (version={app_version}, environment={environment})"
    );

    HttpServer::new(move || {
        App::new()
            .wrap(Logger::default())
            .app_data(shared_state.clone())
            .route("/health", web::get().to(health))
            .route("/info", web::get().to(info))
            .service(
                web::resource("/todos")
                    .route(web::get().to(get_todos))
                    .route(web::post().to(create_todo)),
            )
            .service(
                web::resource("/todos/{id}")
                    .route(web::get().to(get_todo))
                    .route(web::put().to(update_todo))
                    .route(web::delete().to(delete_todo)),
            )
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}
