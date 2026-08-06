import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from sqlalchemy.exc import DBAPIError, OperationalError

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
    if settings.ENVIRONMENT in ("local", "dev", "prod"):
        try:
            from app.core.seed import seed_local_database

            seed_local_database()
            logger.info("Local bootstrap seed complete.")
        except Exception as exc:
            logger.warning("Local seed skipped/failed: %s", exc)
    yield



app = FastAPI(
    title="B2B Modular Monolith API",
    version="1.0.0",
    lifespan=lifespan,
)


@app.exception_handler(OperationalError)
@app.exception_handler(DBAPIError)
async def database_unavailable_handler(request: Request, exc: Exception):
    logger.error("Database unavailable on %s: %s", request.url.path, exc)
    return JSONResponse(status_code=500, content={"detail": "database unavailable"})


STATIC_DIR = Path(__file__).parent / "static"


@app.get("/health", tags=["system"])
async def health():
    return {"status": "healthy"}


@app.get("/seed", tags=["system"])
async def trigger_seed():
    try:
        from app.core.seed import seed_local_database

        seed_local_database()
        return {"status": "seeded", "message": "Database successfully populated with catalog!"}
    except Exception as exc:
        logger.error("Seeding error: %s", exc)
        return JSONResponse(status_code=500, content={"status": "error", "detail": str(exc)})



@app.get("/store", include_in_schema=False)
async def storefront():
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/", include_in_schema=False)
async def root_redirect():
    return RedirectResponse(url="/store")


app.include_router(auth_router, prefix="/auth")
app.include_router(product_router, prefix="/products")
app.include_router(order_router, prefix="/orders")
app.include_router(payment_router, prefix="/payments")
app.include_router(notification_router, prefix="/notifications")
