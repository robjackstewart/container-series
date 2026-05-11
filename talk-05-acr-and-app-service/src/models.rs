use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Todo {
    pub id: String,
    pub title: String,
    pub description: String,
    pub completed: bool,
    pub created_at: DateTime<Utc>,
}

impl fmt::Display for Todo {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "Todo[id={}, title={}, completed={}, created_at={}]",
            self.id, self.title, self.completed, self.created_at
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodoCreateRequest {
    pub title: String,
    pub description: String,
}

impl fmt::Display for TodoCreateRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "TodoCreateRequest[title={}]", self.title)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodoUpdateRequest {
    pub title: String,
    pub description: String,
    pub completed: bool,
}

impl fmt::Display for TodoUpdateRequest {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "TodoUpdateRequest[title={}, completed={}]",
            self.title, self.completed
        )
    }
}
