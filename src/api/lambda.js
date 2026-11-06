// AWS Lambda entry point: wraps the same Express app used locally (server.js is not used in Lambda).
import serverless from 'serverless-http';

import { app } from './app.js';

export const handler = serverless(app);