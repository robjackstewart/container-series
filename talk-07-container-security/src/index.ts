import express, { ErrorRequestHandler, NextFunction, Request, Response } from 'express';
import healthRouter from './routes/health';
import itemsRouter from './routes/items';

const app = express();
const port = Number(process.env.PORT ?? 3000);
const nodeEnv = process.env.NODE_ENV ?? 'development';

app.use(express.json());

app.use('/health', healthRouter);
app.use('/items', itemsRouter);

app.use((req: Request, res: Response) => {
  res.status(404).json({
    message: `Route not found: ${req.method} ${req.originalUrl}`
  });
});

const errorHandler: ErrorRequestHandler = (error: unknown, _req: Request, res: Response, _next: NextFunction) => {
  const message = error instanceof Error ? error.message : 'Internal server error';

  console.error('Unhandled error:', error);

  res.status(500).json({
    message,
    environment: nodeEnv === 'production' ? 'production' : 'development'
  });
};

app.use(errorHandler);

app.listen(port, () => {
  console.log(`Talk 7 API listening on port ${port} (${nodeEnv})`);
});
