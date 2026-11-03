// Código de la función Lambda que genera recomendaciones de contenido.

use lambda_runtime::{handler_fn, Context, Error};
use serde_json::Value;

async fn function_handler(event: Value, _: Context) -> Result<Value, Error> {
    let user_id = event["user_id"].as_i64().unwrap();
    let recommendations = recommend_content(user_id as i32);
    Ok(json!({ "recommendations": recommendations }))
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    let func = handler_fn(function_handler);
    lambda_runtime::run(func).await?;
    Ok(())
}
