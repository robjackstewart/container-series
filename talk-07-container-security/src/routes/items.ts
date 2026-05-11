import { randomUUID } from 'crypto';
import { Request, RequestHandler, Response, Router } from 'express';
import { body, param, validationResult } from 'express-validator';

export interface Item {
  id: string;
  name: string;
  description?: string;
  createdAt: string;
}

const items = new Map<string, Item>();

items.set('11111111-1111-1111-1111-111111111111', {
  id: '11111111-1111-1111-1111-111111111111',
  name: 'Secure base image review',
  description: 'Compare base image CVEs before hardening the runtime image.',
  createdAt: new Date().toISOString()
});

const router = Router();

const validate: RequestHandler = (req, res, next) => {
  const result = validationResult(req);

  if (!result.isEmpty()) {
    return res.status(400).json({
      message: 'Validation failed',
      errors: result.array()
    });
  }

  return next();
};

const itemIdValidation = [param('id').isUUID().withMessage('id must be a valid UUID'), validate];

router.get('/', (_req, res) => {
  res.status(200).json({
    count: items.size,
    items: Array.from(items.values())
  });
});

router.post(
  '/',
  [
    body('name')
      .isString()
      .withMessage('name must be a string')
      .bail()
      .trim()
      .isLength({ min: 1, max: 100 })
      .withMessage('name is required and must be 100 characters or fewer'),
    body('description')
      .optional()
      .isString()
      .withMessage('description must be a string')
      .bail()
      .trim()
      .isLength({ max: 500 })
      .withMessage('description must be 500 characters or fewer'),
    validate
  ],
  (req: Request, res: Response) => {
    const item: Item = {
      id: randomUUID(),
      name: req.body.name,
      description: req.body.description,
      createdAt: new Date().toISOString()
    };

    items.set(item.id, item);

    res.status(201).json(item);
  }
);

router.get('/:id', itemIdValidation, (req: Request, res: Response) => {
  const item = items.get(req.params.id);

  if (!item) {
    return res.status(404).json({ message: 'Item not found' });
  }

  return res.status(200).json(item);
});

router.delete('/:id', itemIdValidation, (req: Request, res: Response) => {
  if (!items.has(req.params.id)) {
    return res.status(404).json({ message: 'Item not found' });
  }

  items.delete(req.params.id);

  return res.status(204).send();
});

export default router;
