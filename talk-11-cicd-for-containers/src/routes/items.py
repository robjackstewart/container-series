from __future__ import annotations

from fastapi import APIRouter, HTTPException, Response, status

from src.models import Item, ItemCreate

router = APIRouter(prefix="/items", tags=["items"])
ITEMS: dict[int, Item] = {}


def _next_id() -> int:
    return max(ITEMS.keys(), default=0) + 1


def _item_payload(payload: ItemCreate) -> dict[str, object]:
    if hasattr(payload, "model_dump"):
        return payload.model_dump()
    return payload.dict()


@router.get("", response_model=list[Item])
def list_items() -> list[Item]:
    return sorted(ITEMS.values(), key=lambda item: item.id)


@router.post("", response_model=Item, status_code=status.HTTP_201_CREATED)
def create_item(payload: ItemCreate) -> Item:
    item = Item(id=_next_id(), **_item_payload(payload))
    ITEMS[item.id] = item
    return item


@router.get("/{item_id}", response_model=Item)
def get_item(item_id: int) -> Item:
    item = ITEMS.get(item_id)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int) -> Response:
    if item_id not in ITEMS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    del ITEMS[item_id]
    return Response(status_code=status.HTTP_204_NO_CONTENT)
