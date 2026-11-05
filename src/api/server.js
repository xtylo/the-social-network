// Entry point: starts the HTTP server (like Program.cs + app.Run()).
import { app } from './app.js';
import { logger } from './logger.js';

const port = Number(process.env.API_PORT ?? 3000);

app.listen(port, () => {
  logger.info(`api listening on port ${port}`);
});