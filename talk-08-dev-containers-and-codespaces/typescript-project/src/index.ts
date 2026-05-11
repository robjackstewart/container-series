import express from "express";

const app = express();
const port = Number(process.env.PORT ?? 3000);

const items = [
  { id: 1, name: "workspace consistency" },
  { id: 2, name: "dev container features" },
  { id: 3, name: "github codespaces" },
];

app.get("/", (_req, res) => {
  res.json({ message: "Welcome to the TypeScript API for Dev Containers & GitHub Codespaces" });
});

app.get("/items", (_req, res) => {
  res.json({ items });
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`TypeScript API listening on port ${port}`);
});
