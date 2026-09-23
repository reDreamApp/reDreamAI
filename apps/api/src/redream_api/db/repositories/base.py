"""Shared async CRUD for the per-model repositories."""

from __future__ import annotations

from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from ..base import Base


class BaseRepo[ModelT: Base]:
    """Adds/saves/deletes rows of a single model, committing each call."""

    model: type[ModelT]

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, row_id: Any) -> ModelT | None:
        return await self.db.get(self.model, row_id)

    async def create(self, row: ModelT) -> ModelT:
        self.db.add(row)
        return await self.save(row)

    async def save(self, row: ModelT) -> ModelT:
        await self.db.commit()
        await self.db.refresh(row)
        return row

    async def delete(self, row: ModelT) -> None:
        await self.db.delete(row)
        await self.db.commit()
