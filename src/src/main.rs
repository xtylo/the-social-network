mod error;
mod models;
mod recommendation_engine;
mod repository;

use std::time::Duration;

use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    routing::get,
};
use serde::Serialize;
use sqlx::postgres::{PgPool, PgPoolOptions};

use crate::error::AppError;
use crate::models::RecommendationsResponse;

/// How many candidates we ask pgvector for, and how many we return.
const CANDIDATES: i64 = 50;
const RESULTS: usize = 10;
/// Diversity rule: at most this many items from the same creator in one response.
const MAX_PER_CREATOR: usize = 2;

/// Shared state for every request (like a singleton registered in ASP.NET Core DI).
/// `Clone` is cheap: PgPool is internally an Arc, so clones share the same pool.
#[derive(Clone)]
struct AppState {
    db: PgPool,
}

#[derive(Serialize)]
struct HealthResponse {
    status: &'static str,
    pgvector: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    // Configuration from environment variables (the dev container already sets DATABASE_URL).
    let database_url = std::env::var("DATABASE_URL").map_err(|_| "DATABASE_URL is not set")?;
    let port = std::env::var("RECO_PORT").unwrap_or_else(|_| "8080".to_string());

    // Connection pool: opened once at startup and reused by every request.
    let db = PgPoolOptions::new()
        .max_connections(10)
        .acquire_timeout(Duration::from_secs(3))
        .connect(&database_url)
        .await?;

    let app = Router::new()
        .route("/health", get(health))
        .route("/recommendations/{user_id}", get(recommendations))
        .with_state(AppState { db });

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await?;
    tracing::info!("reco service listening on port {port}");
    axum::serve(listener, app).await?;
    Ok(())
}

/// GET /health -> 200 with the pgvector version, or 503 if the database is unreachable.
async fn health(State(state): State<AppState>) -> Result<Json<HealthResponse>, StatusCode> {
    let version: String =
        sqlx::query_scalar("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
            .fetch_one(&state.db)
            .await
            .map_err(|e| {
                tracing::error!(error = %e, "health check failed");
                StatusCode::SERVICE_UNAVAILABLE
            })?;

    Ok(Json(HealthResponse {
        status: "ok",
        pgvector: version,
    }))
}

/// GET /recommendations/{user_id}
async fn recommendations(
    State(state): State<AppState>,
    Path(user_id): Path<i32>,
) -> Result<Json<RecommendationsResponse>, AppError> {
    let (strategy, items) = match repository::user_profile(&state.db, user_id).await? {
        Some(profile) => {
            let candidates =
                repository::nearest_unseen(&state.db, user_id, &profile, CANDIDATES).await?;
            let items = recommendation_engine::rerank(candidates, MAX_PER_CREATOR, RESULTS);
            ("personalized", items)
        }
        None => (
            "trending",
            repository::trending(&state.db, RESULTS as i64).await?,
        ),
    };

    Ok(Json(RecommendationsResponse {
        user_id,
        strategy,
        items,
    }))
}
