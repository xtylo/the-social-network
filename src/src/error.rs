use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde_json::json;

/// Application error type. Every handler returns `Result<_, AppError>`,
/// so any `?` on a database call ends up here.
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
}

/// Turns an AppError into an HTTP response (like an exception-handling middleware in ASP.NET Core).
/// The real error goes to the log; the client only gets a generic message.
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        tracing::error!(error = %self, "request failed");
        let body = Json(json!({ "error": "internal server error" }));
        (StatusCode::INTERNAL_SERVER_ERROR, body).into_response()
    }
}
