from __future__ import annotations

from uuid import UUID

from ..models.user import User
from .base import BaseRepo


class UserRepo(BaseRepo[User]):
    model = User

    async def get(self, user_id: UUID) -> User | None:
        return await self.get_by_id(user_id)

    async def upsert_from_supabase(self, *, user_id: UUID, email: str | None) -> User:
        existing = await self.get_by_id(user_id)
        if existing is None:
            return await self.create(User(id=user_id, email=email))
        if email and existing.email != email:
            existing.email = email
            await self.db.commit()
        return existing

    async def delete_by_id(self, user_id: UUID) -> None:
        user = await self.get_by_id(user_id)
        if user is not None:
            await self.delete(user)
