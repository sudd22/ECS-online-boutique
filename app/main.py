"""Single FastAPI entrypoint: global lifespan + module router mounting."""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse, RedirectResponse

from app.config import settings
from app.modules.auth.routes import router as auth_router
from app.modules.notification.routes import router as notification_router
from app.modules.order.routes import router as order_router
from app.modules.payment.routes import router as payment_router
from app.modules.product.routes import router as product_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Bootstrap the local environment automatically on startup."""
    if settings.ENVIRONMENT in ("local", "dev"):
        try:
            from app.core.seed import seed_local_database

            seed_local_database()
            logger.info("Local bootstrap seed complete.")
        except Exception as exc:  # noqa: BLE001 - never block startup on seed
            logger.warning("Local seed skipped/failed: %s", exc)
    yield


app = FastAPI(
    title="B2B Modular Monolith API",
    version="1.0.0",
    lifespan=lifespan,
)


STATIC_DIR = Path(__file__).parent / "static"


@app.get("/health", tags=["system"])
async def health():
    """Shallow, unauthenticated health probe for ALB target groups / Docker."""
    return {"status": "healthy"}


@app.get("/store", include_in_schema=False)
async def storefront():
    """Serve the self-contained single-file storefront UI."""
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/", include_in_schema=False)
async def root_redirect():
    """Send the bare host to the storefront for a friendly landing page."""
    return RedirectResponse(url="/store")


app.include_router(auth_router, prefix="/auth")
app.include_router(product_router, prefix="/products")
app.include_router(order_router, prefix="/orders")
app.include_router(payment_router, prefix="/payments")
app.include_router(notification_router, prefix="/notifications")
