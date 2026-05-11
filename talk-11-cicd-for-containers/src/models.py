from __future__ import annotations

from pydantic import BaseModel, Field


class ItemCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    price: float = Field(default=0.0, ge=0)
    available: bool = True


class ItemUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    price: float | None = Field(default=None, ge=0)
    available: bool | None = None


class Item(ItemCreate):
    id: int
