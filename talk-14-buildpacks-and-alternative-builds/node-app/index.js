const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
app.use(express.json());

const items = [{id: 1, name: 'Node Widget'}];

app.get('/', (req, res) => res.json({message: 'Hello from Node.js!', note: 'Built with Nixpacks - no Dockerfile needed!'}));
app.get('/health', (req, res) => res.json({status: 'healthy'}));
app.get('/items', (req, res) => res.json(items));
app.post('/items', (req, res) => { const item = {id: items.length + 1, ...req.body}; items.push(item); res.status(201).json(item); });

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
