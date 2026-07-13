"""Zero-ops idempotent local database seeder.

Goal: a reviewer can `docker compose up` and immediately have a usable schema
plus realistic baseline data with zero manual steps.
"""

import logging
from decimal import Decimal

from sqlalchemy import select

from app.core.database import Base, SessionLocal, engine

logger = logging.getLogger("seed")


def seed_local_database() -> None:
    """Create all tables (idempotently) and seed baseline demo data."""
    # CRITICAL FIX: import every domain model BEFORE touching metadata so all
    # tables are registered on Base.metadata prior to create_all().
    from app.modules.auth.models import Tenant, User  # noqa: F401
    from app.modules.notification.models import Notification  # noqa: F401
    from app.modules.order.models import Order, OrderItem  # noqa: F401
    from app.modules.payment.models import Payment  # noqa: F401
    from app.modules.product.models import Product  # noqa: F401
    from app.modules.auth.services import hash_password

    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        existing_tenant = db.execute(select(Tenant)).scalars().first()
        if existing_tenant is not None:
            logger.info("Seed skipped: tenant '%s' already present.", existing_tenant.name)
            return

        tenant = Tenant(name="Acme Global Tech", plan="enterprise")
        db.add(tenant)
        db.flush()  # assign tenant.id without committing yet

        recruiter = User(
            email="recruiter@company.com",
            hashed_password=hash_password("password123"),
            tenant_id=tenant.id,
            is_active=True,
        )
        db.add(recruiter)

        sample_products = [
            Product(
                name="Enterprise Cloud Widget",
                description="High-throughput modular automation block for elastic compute pipelines.",
                sku="B2B-WIDGET-001",
                price=Decimal("299.99"),
                stock_quantity=120,
            ),
            Product(
                name="Managed Postgres Datastore",
                description="Fully-managed, horizontally partitioned relational storage cluster.",
                sku="DB-STORE-2002",
                price=Decimal("749.00"),
                stock_quantity=60,
            ),
            Product(
                name="Global Edge CDN Node",
                description="Low-latency content delivery node with anycast networking and TLS termination.",
                sku="NET-CDN-3003",
                price=Decimal("189.99"),
                stock_quantity=200,
            ),
            Product(
                name="Compute Automation Engine",
                description="Event-driven workflow engine with autoscaling worker chips.",
                sku="CMP-ENGINE-4004",
                price=Decimal("1299.00"),
                stock_quantity=30,
            ),
            Product(
                name="Object Storage Vault",
                description="Durable, versioned object storage buckets with lifecycle policies.",
                sku="DB-VAULT-5005",
                price=Decimal("349.50"),
                stock_quantity=150,
            ),
            Product(
                name="Service Mesh Gateway",
                description="Connected node-graph mesh gateway for secure cross-service traffic.",
                sku="NET-MESH-6006",
                price=Decimal("459.00"),
                stock_quantity=90,
            ),
        ]
        db.add_all(sample_products)

        db.commit()
        logger.info(
            "Seeded tenant '%s', recruiter '%s', and %d products.",
            tenant.name,
            recruiter.email,
            len(sample_products),
        )
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
