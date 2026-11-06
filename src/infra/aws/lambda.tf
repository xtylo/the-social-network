# The two Lambdas, built on day 9:
#   Rust: cd src && cargo lambda build --release --arm64 --output-format zip
#   Node: ./scripts/package-api.sh

locals {
  rust_zip = "${path.module}/../../target/lambda/reco/bootstrap.zip"
  api_zip  = "${path.module}/../../../dist/api.zip"

  db_url = "postgres://${aws_db_instance.main.username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${aws_db_instance.main.db_name}"

  lambda_vpc = {
    subnet_ids         = data.aws_subnets.supported.ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Log groups created by Terraform, so they get a short retention and are deleted by `terraform destroy`.
resource "aws_cloudwatch_log_group" "reco" {
  name              = "/aws/lambda/${var.project}-reco"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${var.project}-api"
  retention_in_days = 3
}

resource "aws_lambda_function" "reco" {
  function_name    = "${var.project}-reco"
  role             = aws_iam_role.reco.arn
  runtime          = "provided.al2023" # custom runtime: the zip contains a "bootstrap" binary
  handler          = "bootstrap"
  architectures    = ["arm64"]
  filename         = local.rust_zip
  source_code_hash = filebase64sha256(local.rust_zip) # redeploys only when the zip changes
  memory_size      = 256
  timeout          = 10

  # Cap on concurrent instances. Without it, a traffic spike made Lambda scale to 400 instances, each opening its own
  # database connections, and RDS collapsed under the connection storm (see docs/results.md).
  reserved_concurrent_executions = var.reco_reserved_concurrency

  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }

  environment {
    variables = {
      DATABASE_URL = "${local.db_url}?sslmode=require"
      # One instance serves one request at a time, so one connection is enough.
      DB_MAX_CONNECTIONS = "1"
    }
  }

  depends_on = [aws_cloudwatch_log_group.reco, aws_iam_role_policy_attachment.reco_vpc]
}

resource "aws_lambda_function" "api" {
  function_name    = "${var.project}-api"
  role             = aws_iam_role.api.arn
  runtime          = "nodejs22.x"
  handler          = "lambda.handler" # lambda.js, export "handler"
  architectures    = ["arm64"]
  filename         = local.api_zip
  source_code_hash = filebase64sha256(local.api_zip)
  memory_size      = 512
  timeout          = 10

  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }

  environment {
    variables = {
      DATABASE_URL       = "${local.db_url}?sslmode=no-verify"
      DB_MAX_CONNECTIONS = "2"
      S3_BUCKET          = aws_s3_bucket.content.bucket
      LOG_LEVEL          = "info"
    }
  }

  depends_on = [aws_cloudwatch_log_group.api, aws_iam_role_policy_attachment.api_vpc]
}
