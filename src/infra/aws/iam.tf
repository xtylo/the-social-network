# One IAM role per Lambda (least privilege: each function only gets what it needs).

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "reco" {
  name               = "${var.project}-reco-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role" "api" {
  name               = "${var.project}-api-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# AWS managed policy: CloudWatch Logs + the network interfaces a Lambda needs to run inside a VPC.
resource "aws_iam_role_policy_attachment" "reco_vpc" {
  role       = aws_iam_role.reco.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_vpc" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Only the Node API touches S3: sign upload URLs (PutObject) and check uploads exist (HeadObject = GetObject).
# ListBucket makes HeadObject on a missing file return 404 instead of 403, which the API relies on.
data "aws_iam_policy_document" "api_s3" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.content.arn]
  }
}

resource "aws_iam_role_policy" "api_s3" {
  name   = "s3-content-bucket"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_s3.json
}
