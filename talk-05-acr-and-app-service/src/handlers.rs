use crate::models::{Todo, TodoCreateRequest, TodoUpdateRequest};
use actix_web::{
    http::StatusCode,
    web::{self, Data, Json, Path},
    HttpResponse, ResponseError,
};
use chrono::Utc;
use serde::Serialize;
use serde_json::json;
use std::{fmt, sync::{Arc, Mutex}};
use uuid::Uuid;

#[derive(Clone)]
pub struct AppState {
    pub todos: Arc<Mutex<Vec<Todo>>>,
    pub app_version: String,
    pub environment: String,
}

#[derive(Debug)]
pub enum AppError {
    BadRequest(String),
    NotFound(String),
    Internal(String),
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    error: String,
}

#[derive(Debug, Serialize)]
pub struct InfoResponse {
    pub app_version: String,
    pub environment: String,
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadRequest(message) => write!(f, "{message}"),
            Self::NotFound(message) => write!(f, "{message}"),
            Self::Internal(message) => write!(f, "{message}"),
        }
    }
}

impl ResponseError for AppError {
    fn status_code(&self) -> StatusCode {
        match self {
            Self::BadRequest(_) => StatusCode::BAD_REQUEST,
            Self::NotFound(_) => StatusCode::NOT_FOUND,
            Self::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code()).json(ErrorResponse {
            error: self.to_string(),
        })
    }
}

fn validate_title(title: &str) -> Result<(), AppError> {
    if title.trim().is_empty() {
        return Err(AppError::BadRequest(
            "title must not be empty".to_string(),
        ));
    }

    Ok(())
}

fn lock_todos(state: &Data<AppState>) -> Result<std::sync::MutexGuard<'_, Vec<Todo>>, AppError> {
    state
        .todos
        .lock()
        .map_err(|_| AppError::Internal("failed to acquire todo store lock".to_string()))
}

pub async fn health() -> HttpResponse {
    HttpResponse::Ok().json(json!({ "status": "ok" }))
}

pub async fn info(state: Data<AppState>) -> HttpResponse {
    HttpResponse::Ok().json(InfoResponse {
        app_version: state.app_version.clone(),
        environment: state.environment.clone(),
    })
}

pub async fn get_todos(state: Data<AppState>) -> Result<HttpResponse, AppError> {
    let todos = lock_todos(&state)?;
    Ok(HttpResponse::Ok().json(todos.clone()))
}

pub async fn create_todo(
    state: Data<AppState>,
    payload: Json<TodoCreateRequest>,
) -> Result<HttpResponse, AppError> {
    validate_title(&payload.title)?;

    let todo = Todo {
        id: Uuid::new_v4().to_string(),
        title: payload.title.trim().to_string(),
        description: payload.description.trim().to_string(),
        completed: false,
        created_at: Utc::now(),
    };

    let mut todos = lock_todos(&state)?;
    todos.push(todo.clone());

    Ok(HttpResponse::Created().json(todo))
}

pub async fn get_todo(
    state: Data<AppState>,
    todo_id: Path<String>,
) -> Result<HttpResponse, AppError> {
    let todo_id = todo_id.into_inner();
    let todos = lock_todos(&state)?;

    let todo = todos
        .iter()
        .find(|todo| todo.id == todo_id)
        .cloned()
        .ok_or_else(|| AppError::NotFound(format!("todo {todo_id} was not found")))?;

    Ok(HttpResponse::Ok().json(todo))
}

pub async fn update_todo(
    state: Data<AppState>,
    todo_id: Path<String>,
    payload: Json<TodoUpdateRequest>,
) -> Result<HttpResponse, AppError> {
    validate_title(&payload.title)?;

    let todo_id = todo_id.into_inner();
    let mut todos = lock_todos(&state)?;

    let todo = todos
        .iter_mut()
        .find(|todo| todo.id == todo_id)
        .ok_or_else(|| AppError::NotFound(format!("todo {todo_id} was not found")))?;

    todo.title = payload.title.trim().to_string();
    todo.description = payload.description.trim().to_string();
    todo.completed = payload.completed;

    Ok(HttpResponse::Ok().json(todo.clone()))
}

pub async fn delete_todo(
    state: Data<AppState>,
    todo_id: Path<String>,
) -> Result<HttpResponse, AppError> {
    let todo_id = todo_id.into_inner();
    let mut todos = lock_todos(&state)?;

    let todo_position = todos
        .iter()
        .position(|todo| todo.id == todo_id)
        .ok_or_else(|| AppError::NotFound(format!("todo {todo_id} was not found")))?;

    todos.remove(todo_position);
    Ok(HttpResponse::NoContent().finish())
}
