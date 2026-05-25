"""
InsightHub API — Health & readiness
/healthz : liveness — process còn sống
/readyz  : readiness — DB sẵn sàng nhận traffic
"""
from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.core.db import healthcheck

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def liveness():
    return {"status": "ok"}


@router.get("/readyz")
async def readiness():
    db_ok = healthcheck()
    if not db_ok:
        return JSONResponse(status_code=503, content={"status": "not_ready", "db": False})
    return {"status": "ready", "db": True}
