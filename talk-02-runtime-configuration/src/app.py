from __future__ import annotations

import os
from dataclasses import asdict, dataclass
from http import HTTPStatus
from pathlib import Path
from threading import Lock
from typing import Any

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from werkzeug.exceptions import HTTPException

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env", override=False)
load_dotenv(override=False)

REQUIRED_ENV_VARS = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "APP_SECRET_KEY")
DATABASE_ENV_VARS = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER")


class APIError(Exception):
    def __init__(self, message: str, status_code: int = HTTPStatus.BAD_REQUEST) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = int(status_code)


@dataclass(frozen=True)
class RuntimeConfig:
    db_host: str | None
    db_port: int | None
    db_name: str | None
    db_user: str | None
    app_secret_key: str | None
    app_env: str

    @classmethod
    def from_env(cls) -> "RuntimeConfig":
        raw_port = os.getenv("DB_PORT")
        db_port: int | None = None
        if raw_port:
            try:
                db_port = int(raw_port)
            except ValueError:
                db_port = None

        return cls(
            db_host=os.getenv("DB_HOST"),
            db_port=db_port,
            db_name=os.getenv("DB_NAME"),
            db_user=os.getenv("DB_USER"),
            app_secret_key=os.getenv("APP_SECRET_KEY"),
            app_env=os.getenv("APP_ENV", "development"),
        )

    def env_checks(self) -> dict[str, bool]:
        checks: dict[str, bool] = {}
        for key in REQUIRED_ENV_VARS:
            value = os.getenv(key)
            checks[key] = value is not None and bool(str(value).strip())
        checks["DB_PORT"] = checks["DB_PORT"] and self.db_port is not None
        return checks

    def missing_required(self) -> list[str]:
        return [key for key, is_valid in self.env_checks().items() if not is_valid]

    def missing_database_config(self) -> list[str]:
        checks = self.env_checks()
        return [key for key in DATABASE_ENV_VARS if not checks[key]]

    def connection_string(self) -> str:
        if self.missing_database_config():
            raise APIError("Database configuration is incomplete; cannot create database target.", HTTPStatus.SERVICE_UNAVAILABLE)
        return f"postgresql://{self.db_user}@{self.db_host}:{self.db_port}/{self.db_name}"

    def public_view(self) -> dict[str, Any]:
        payload = asdict(self)
        payload.pop("app_secret_key", None)
        payload["app_secret_key_configured"] = bool(self.app_secret_key)
        payload["connection_target"] = (
            f"{self.db_host}:{self.db_port}/{self.db_name}" if self.db_host and self.db_port and self.db_name else None
        )
        return payload


class ItemStore:
    def __init__(self) -> None:
        self._items: list[dict[str, Any]] = [
            {"id": 1, "name": "container-basics", "description": "Recap from Talk 1"},
            {"id": 2, "name": "runtime-config", "description": "Configuration is injected at runtime"},
        ]
        self._lock = Lock()
        self._next_id = len(self._items) + 1

    def list_items(self) -> list[dict[str, Any]]:
        with self._lock:
            return [item.copy() for item in self._items]

    def add_item(self, name: str, description: str | None = None) -> dict[str, Any]:
        if not name.strip():
            raise APIError("Field 'name' must not be empty.")

        with self._lock:
            item = {
                "id": self._next_id,
                "name": name.strip(),
                "description": (description or "").strip(),
            }
            self._items.append(item)
            self._next_id += 1
            return item.copy()


store = ItemStore()


def create_app() -> Flask:
    app = Flask(__name__)
    config = RuntimeConfig.from_env()
    app.config["JSON_SORT_KEYS"] = False
    app.secret_key = config.app_secret_key or "development-only-fallback"

    @app.get("/health")
    def health() -> tuple[Any, int]:
        runtime_config = RuntimeConfig.from_env()
        checks = runtime_config.env_checks()
        missing = [key for key, is_valid in checks.items() if not is_valid]
        is_healthy = not missing
        status = HTTPStatus.OK if is_healthy else HTTPStatus.SERVICE_UNAVAILABLE

        return (
            jsonify(
                {
                    "status": "ok" if is_healthy else "degraded",
                    "checks": checks,
                    "missing": missing,
                    "environment": runtime_config.app_env,
                }
            ),
            status,
        )

    @app.get("/config")
    def get_config() -> Any:
        runtime_config = RuntimeConfig.from_env()
        return jsonify(runtime_config.public_view())

    @app.get("/items")
    def get_items() -> Any:
        runtime_config = RuntimeConfig.from_env()
        connection_string = runtime_config.connection_string()
        items = store.list_items()
        return jsonify(
            {
                "items": items,
                "count": len(items),
                "database_target": connection_string,
            }
        )

    @app.post("/items")
    def create_item() -> tuple[Any, int]:
        payload = request.get_json(silent=True)
        if payload is None:
            raise APIError("Request body must be valid JSON.")
        if not isinstance(payload, dict):
            raise APIError("JSON payload must be an object.")

        name = payload.get("name")
        if not isinstance(name, str):
            raise APIError("Field 'name' is required and must be a string.")

        description = payload.get("description")
        if description is not None and not isinstance(description, str):
            raise APIError("Field 'description' must be a string when provided.")

        item = store.add_item(name=name, description=description)
        return jsonify(item), HTTPStatus.CREATED

    @app.errorhandler(APIError)
    def handle_api_error(error: APIError) -> tuple[Any, int]:
        return jsonify({"error": error.message}), error.status_code

    @app.errorhandler(HTTPException)
    def handle_http_error(error: HTTPException) -> tuple[Any, int]:
        response = error.get_response()
        response.data = jsonify({"error": error.description}).get_data()
        response.content_type = "application/json"
        return response, error.code or HTTPStatus.INTERNAL_SERVER_ERROR

    @app.errorhandler(Exception)
    def handle_unexpected_error(error: Exception) -> tuple[Any, int]:
        app.logger.exception("Unhandled exception while serving request", exc_info=error)
        return jsonify({"error": "Internal server error"}), HTTPStatus.INTERNAL_SERVER_ERROR

    return app


app = create_app()


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
