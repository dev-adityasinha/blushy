import { createServer } from 'node:http';

import app from './app.js';
import { env } from './utils/env.js';
import { initDatabase } from './utils/initDatabase.js';
import { logger } from './utils/logger.js';
import { initRealtimeHub } from './utils/realtimeHub.js';
import { startCommunityCleanupScheduler } from './services/communityCleanupService.js';
import { startDailyChatSummaryScheduler } from './services/dailyChatSummaryService.js';

const port = env.port;
let stopCommunityCleanupScheduler = () => {};
let stopDailyChatSummaryScheduler = () => {};

const server = createServer(app);

async function start() {
  await initDatabase();
  initRealtimeHub(server);
  stopCommunityCleanupScheduler = startCommunityCleanupScheduler();
  stopDailyChatSummaryScheduler = startDailyChatSummaryScheduler();

  server.listen(port, () => {
    logger.info(`Blushy auth backend listening on port ${port}`);
  });
}

start().catch((error) => {
  logger.error(`Failed to start server: ${error?.message ?? error}`);
  process.exit(1);
});

process.on('SIGINT', () => {
  logger.info('Shutting down gracefully');
  stopCommunityCleanupScheduler();
  stopDailyChatSummaryScheduler();
  server.close(() => process.exit(0));
});