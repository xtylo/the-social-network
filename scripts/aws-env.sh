# Switches THIS terminal from Floci (local S3 emulator) to real AWS, using the "tsn" profile.
# Usage (from the repo root): source scripts/aws-env.sh
# Open a new terminal to go back to the local setup.
unset AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=tsn
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
echo "Using real AWS as: $(aws sts get-caller-identity --query Arn --output text)"
