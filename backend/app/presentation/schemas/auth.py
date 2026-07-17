from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class RoleSchema(StrEnum):
    USER = "user"
    SUPER_ADMIN = "super_admin"


class UserBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    email: EmailStr
    phone: str | None = None
    role: RoleSchema
    locale: str
    theme: str


class UserWithPlan(UserBase):
    force_password_change: bool
    plan: dict[str, Any] | None = None


class AuthResponse(BaseModel):
    user: UserWithPlan
    access_token: str
    refresh_token: str
    force_password_change: bool = False


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    phone: str | None = Field(default=None, max_length=32)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("password")
    @classmethod
    def _strong_enough(cls, v: str) -> str:
        if not any(c.isdigit() for c in v) or not any(c.isalpha() for c in v):
            raise ValueError("Senha deve conter letras e números")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class PasswordForgotRequest(BaseModel):
    email: EmailStr


class PasswordResetRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class UpdateProfileRequest(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = None
    locale: str | None = Field(default=None, pattern=r"^(pt-BR|en)$")
    theme: str | None = Field(default=None, pattern=r"^(dark|light)$")


class PlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    code: str
    name: str
    price_monthly_cents: int
    price_yearly_cents: int
    limits_json: dict[str, Any]