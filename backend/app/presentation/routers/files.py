from __future__ import annotations

import os
import secrets
import shutil
import uuid
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import RedirectResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.infrastructure.database.models import FileAsset, FileCategory, MinPlan
from app.infrastructure.database.session import get_db
from app.presentation.deps.auth import get_current_user, require_super_admin

router = APIRouter()


def _storage_root() -> Path:
    p = Path(settings.uploads_base_dir).resolve()
    p.mkdir(parents=True, exist_ok=True)
    return p


def _plan_rank(plan_code: str | None) -> int:
    return {"free": 0, "pro": 1, "premium": 2}.get(plan_code or "free", 0)


@router.get("/files")
def list_files(user=Depends(get_current_user), db: Session = Depends(get_db), category: str | None = None) -> dict:
    user_plan = getattr(user, "_plan_payload", None) or {"code": "free"}
    user_rank = _plan_rank(user_plan["code"])
    stmt = select(FileAsset).where(FileAsset.is_active == True)  # noqa: E712
    if category:
        stmt = stmt.where(FileAsset.category == category)
    files = db.scalars(stmt.order_by(FileAsset.created_at.desc())).all()
    items = [
        {
            "id": f.id,
            "title": f.title,
            "description": f.description,
            "version": f.version,
            "category": f.category.value,
            "size_bytes": f.size_bytes,
            "min_plan": f.min_plan.value,
            "created_at": f.created_at.isoformat(),
            "allowed": _plan_rank(f.min_plan.value) <= user_rank,
        }
        for f in files
    ]
    return {"items": items}


@router.post("/files/{file_id}/download-url")
def download_url(file_id: uuid.UUID, user=Depends(get_current_user), db: Session = Depends(get_db)) -> dict:
    user_plan = getattr(user, "_plan_payload", None) or {"code": "free"}
    user_rank = _plan_rank(user_plan["code"])
    f = db.get(FileAsset, file_id)
    if f is None or not f.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "file not found")
    if _plan_rank(f.min_plan.value) > user_rank:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "plan_insufficient")
    path = _storage_root() / f.storage_key
    if not path.exists():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "file missing from storage")
    return {"url": f"/api/v1/files/{f.id}/raw", "expires_in": 300}


@router.get("/files/{file_id}/raw")
def download_raw(file_id: uuid.UUID, user=Depends(get_current_user), db: Session = Depends(get_db)):
    from fastapi.responses import FileResponse

    user_plan = getattr(user, "_plan_payload", None) or {"code": "free"}
    user_rank = _plan_rank(user_plan["code"])
    f = db.get(FileAsset, file_id)
    if f is None or not f.is_active:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "file not found")
    if _plan_rank(f.min_plan.value) > user_rank:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "plan_insufficient")
    path = _storage_root() / f.storage_key
    if not path.exists():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "file missing from storage")
    return FileResponse(path, filename=f.title)


@router.post("/files", status_code=status.HTTP_201_CREATED)
def upload_file(
    title: str = Form(...),
    version: str = Form(...),
    category: Literal["robo_mt5", "indicador", "manual", "outros"] = Form(...),
    min_plan: Literal["free", "pro", "premium"] = Form("free"),
    description: str | None = Form(None),
    is_active: bool = Form(True),
    file: UploadFile = File(...),
    admin=Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> dict:
    if not file.filename:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "empty filename")
    ext = Path(file.filename).suffix.lstrip(".").lower()
    if ext not in settings.uploads_allowed_exts:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, f"extension .{ext} not allowed")
    storage_root = _storage_root()
    saved_name = f"{uuid.uuid4().hex}.{ext}"
    final_path = storage_root / saved_name
    size = 0
    max_bytes = settings.uploads_max_size_mb * 1024 * 1024
    with final_path.open("wb") as out:
        while True:
            chunk = file.file.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            if size > max_bytes:
                out.close()
                final_path.unlink(missing_ok=True)
                raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "file too large")
            out.write(chunk)
    file_row = FileAsset(
        title=title,
        description=description,
        version=version,
        category=FileCategory(category),
        min_plan=MinPlan(min_plan),
        is_active=is_active,
        storage_key=saved_name,
        size_bytes=size,
        mime_type=file.content_type or "application/octet-stream",
        uploaded_by=admin.id,
    )
    db.add(file_row)
    db.commit()
    return {"id": file_row.id, "title": file_row.title, "size_bytes": file_row.size_bytes}


@router.patch("/files/{file_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def update_file_metadata(
    file_id: uuid.UUID,
    title: str | None = None,
    description: str | None = None,
    min_plan: Literal["free", "pro", "premium"] | None = None,
    is_active: bool | None = None,
    admin=Depends(require_super_admin),
    db: Session = Depends(get_db),
) -> None:
    f = db.get(FileAsset, file_id)
    if f is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "file not found")
    if title is not None:
        f.title = title
    if description is not None:
        f.description = description
    if min_plan is not None:
        f.min_plan = MinPlan(min_plan)
    if is_active is not None:
        f.is_active = is_active
    db.commit()


@router.delete("/files/{file_id}", status_code=status.HTTP_204_NO_CONTENT, response_model=None)
def delete_file(file_id: uuid.UUID, admin=Depends(require_super_admin), db: Session = Depends(get_db)) -> None:
    f = db.get(FileAsset, file_id)
    if f is None:
        return
    path = _storage_root() / f.storage_key
    path.unlink(missing_ok=True)
    db.delete(f)
    db.commit()