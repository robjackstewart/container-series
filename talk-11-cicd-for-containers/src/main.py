from __future__ import annotations

import os

from fastapi import FastAPI

from src.routes import items

PORT = int(os.getenv("PORT", "8000"))
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
APP_VERSION = os.getenv("APP_VERSION", "0.1.0")

app = FastAPI(
    title="Talk 11 FastAPI App",
    description="Sample API for CI/CD pipeline demonstrations.",
    version=APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.include_router(items.router)


@app.get("/", tags=["meta"])
def read_root() -> dict[str, object]:
    return {
        "message": "Welcome to Talk 11: CI/CD Pipelines for Containerised Applications",
        "environment": ENVIRONMENT,
        "version": APP_VERSION,
        "port": PORT,
        "docs": "/docs",
    }


@app.get("/health", tags=["meta"])
def health_check() -> dict[str, object]:
    return {
        "status": "ok",
        "environment": ENVIRONMENT,
        "version": APP_VERSION,
        "item_count": len(items.ITEMS),
    }
