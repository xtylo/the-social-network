use serde::Serialize;

/// One recommended content item. `FromRow` maps SQL columns to fields by name (like Dapper).
#[derive(Debug, Clone, Serialize, sqlx::FromRow)]
pub struct Recommendation {
    pub id: i32,
    pub creator_id: i32,
    pub title: String,
    pub score: f64,
}

/// JSON returned by GET /recommendations/{user_id}.
#[derive(Debug, Serialize)]
pub struct RecommendationsResponse {
    pub user_id: i32,
    /// "personalized" when the user has a profile, "trending" for cold start.
    pub strategy: &'static str,
    pub items: Vec<Recommendation>,
}
