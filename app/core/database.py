"""SQLAlchemy engine, session pool, and declarative base.

A single shared engine/session factory is used across every module. While the
engine is shared, each module owns its own tables logically and MUST NOT issue
SQL joins across domain boundaries (see the project "Golden Rule").
"""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from app.config import settings

# pool_pre_ping recycles dead connections transparently (important behind a
# Fargate NAT / RDS Proxy where idle connections may be reaped).
engine = create_engine(settings.db_url, pool_pre_ping=True)

# Thread-safe session factory shared by all modules.
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Declarative base shared by every module's models so a single
# metadata.create_all() call can materialize the whole schema.
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency that yields a scoped DB session and closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
