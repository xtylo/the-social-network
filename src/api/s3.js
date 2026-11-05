// S3 client. In the dev container AWS_ENDPOINT_URL points to Floci; in real AWS it is simply not set.
import { S3Client } from '@aws-sdk/client-s3';

export const BUCKET = process.env.S3_BUCKET ?? 'creator-content';

export const s3 = new S3Client({
  region: process.env.AWS_REGION ?? 'us-east-1',
  endpoint: process.env.AWS_ENDPOINT_URL, // undefined in real AWS -> default endpoint
  forcePathStyle: true, // http://floci:4566/bucket/key instead of http://bucket.floci:4566/key
});