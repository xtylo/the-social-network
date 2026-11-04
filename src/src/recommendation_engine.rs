//! Re-ranking rules applied after pgvector returns the nearest candidates.
//! Pure functions: no database, no async, so they are easy to unit test.

use std::collections::HashMap;

use crate::models::Recommendation;

/// Returns at most `n` items, best score first, with no more than
/// `max_per_creator` items from the same creator (so one creator cannot fill the feed).
/// The input does not need to be sorted.
pub fn rerank(
    mut candidates: Vec<Recommendation>,
    max_per_creator: usize,
    n: usize,
) -> Vec<Recommendation> {
    // Highest score first. `total_cmp` orders f64 safely (even NaN), unlike `partial_cmp().unwrap()`.
    candidates.sort_by(|a, b| b.score.total_cmp(&a.score));

    let mut per_creator: HashMap<i32, usize> = HashMap::new();
    let mut result = Vec::with_capacity(n);

    for item in candidates {
        if result.len() == n {
            break;
        }
        let count = per_creator.entry(item.creator_id).or_insert(0);
        if *count < max_per_creator {
            *count += 1;
            result.push(item);
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Test helper: builds a candidate with just the fields that matter here.
    fn item(id: i32, creator_id: i32, score: f64) -> Recommendation {
        Recommendation {
            id,
            creator_id,
            title: format!("post {id}"),
            score,
        }
    }

    #[test]
    fn limits_items_per_creator() {
        // Creator 1 has the 4 best scores, but only 2 of them may get in.
        let candidates = vec![
            item(1, 1, 0.99),
            item(2, 1, 0.98),
            item(3, 1, 0.97),
            item(4, 1, 0.96),
            item(5, 2, 0.90),
            item(6, 3, 0.80),
        ];

        let result = rerank(candidates, 2, 10);

        let from_creator_1 = result.iter().filter(|r| r.creator_id == 1).count();
        assert_eq!(from_creator_1, 2);
        let ids: Vec<i32> = result.iter().map(|r| r.id).collect();
        assert_eq!(ids, vec![1, 2, 5, 6]);
    }

    #[test]
    fn returns_at_most_n_items() {
        let candidates = (1..=50).map(|i| item(i, i, f64::from(i))).collect();

        let result = rerank(candidates, 2, 10);

        assert_eq!(result.len(), 10);
    }

    #[test]
    fn sorts_by_score_descending() {
        let candidates = vec![item(1, 1, 0.5), item(2, 2, 0.9), item(3, 3, 0.7)];

        let result = rerank(candidates, 2, 10);

        let scores: Vec<f64> = result.iter().map(|r| r.score).collect();
        assert_eq!(scores, vec![0.9, 0.7, 0.5]);
    }

    #[test]
    fn empty_input_returns_empty_output() {
        let result = rerank(Vec::new(), 2, 10);

        assert!(result.is_empty());
    }
}
