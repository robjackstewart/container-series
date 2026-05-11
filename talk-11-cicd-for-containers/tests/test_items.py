from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from src.main import app
from src.routes import items as items_module

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_items() -> None:
    items_module.ITEMS.clear()
    yield
    items_module.ITEMS.clear()


def test_get_items_returns_200() -> None:
    response = client.get("/items")

    assert response.status_code == 200
    assert response.json() == []


def test_create_item_returns_201() -> None:
    response = client.post(
        "/items",
        json={"name": "Container Workshop", "description": "Talk asset", "price": 11.0},
    )

    body = response.json()
    assert response.status_code == 201
    assert body["id"] == 1
    assert body["name"] == "Container Workshop"


def test_get_item_returns_200() -> None:
    created = client.post("/items", json={"name": "FastAPI", "price": 12.5}).json()

    response = client.get(f"/items/{created['id']}")

    assert response.status_code == 200
    assert response.json()["name"] == "FastAPI"


def test_get_item_returns_404() -> None:
    response = client.get("/items/999")

    assert response.status_code == 404
    assert response.json()["detail"] == "Item not found"


def test_delete_item_returns_204() -> None:
    created = client.post("/items", json={"name": "Delete me", "price": 1.0}).json()

    response = client.delete(f"/items/{created['id']}")

    assert response.status_code == 204
    assert client.get(f"/items/{created['id']}").status_code == 404


def test_create_item_validates_input() -> None:
    response = client.post("/items", json={"name": "", "price": 5.0})

    assert response.status_code == 422
