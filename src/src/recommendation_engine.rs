// Implementa la lógica de recomendación de contenido utilizando características vectoriales.

use pgvector::Vector;

fn recommend_content(user_id: i32) -> Vec<Content> {
    // Fetch user preferences and content vectors
    let user_vector = fetch_user_vector(user_id);
    let content_vectors = fetch_content_vectors();

    // Calculate similarity scores
    let mut scores: Vec<(Content, f32)> = content_vectors.iter()
        .map(|content| (content, user_vector.similarity(&content.vector)))
        .collect();

    // Sort by score descending
    scores.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

    // Return top recommendations
    scores.into_iter().take(10).map(|(content, _)| content).collect()
}
