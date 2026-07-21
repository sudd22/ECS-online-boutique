import logging
from decimal import Decimal

from sqlalchemy import select

from app.core.database import Base, SessionLocal, engine

logger = logging.getLogger("seed")


CATALOG = [
    {
        "name": "Pilot Sunglasses",
        "description": "Classic aviator sunglasses with UV400 protection lenses.",
        "sku": "B2B-WIDGET-001",
        "price": Decimal("89.00"),
        "stock_quantity": 120,
    },
    {
        "name": "Organic Cotton Tank Top",
        "description": "Breathable, lightweight combed cotton top perfect for layering.",
        "sku": "DB-STORE-2002",
        "price": Decimal("34.00"),
        "stock_quantity": 60,
    },
    {
        "name": "Minimalist Chronograph Watch",
        "description": "Stainless steel quartz watch with a brushed tan leather strap.",
        "sku": "NET-CDN-3003",
        "price": Decimal("249.00"),
        "stock_quantity": 200,
    },
    {
        "name": "Suede Platform Loafers",
        "description": "Hand-stitched premium suede loafers with ergonomic cushioned insoles.",
        "sku": "CMP-ENGINE-4004",
        "price": Decimal("168.00"),
        "stock_quantity": 30,
    },
    {
        "name": "Ionic Travel Hairdryer",
        "description": (
            "Compact 1800W professional hairdryer with folding handle "
            "and heat concentration nozzle."
        ),
        "sku": "DB-VAULT-5005",
        "price": Decimal("79.00"),
        "stock_quantity": 150,
    },
    {
        "name": "Textured Ceramic Candle Holder",
        "description": (
            "Handmade minimalist earthenware vessel designed for standard "
            "tealights or small pillar candles."
        ),
        "sku": "NET-MESH-6006",
        "price": Decimal("42.00"),
        "stock_quantity": 90,
    },
]


def seed_local_database() -> None:
    from app.modules.auth.models import Tenant, User  
    from app.modules.notification.models import Notification  
    from app.modules.order.models import Order, OrderItem  
    from app.modules.payment.models import Payment  
    from app.modules.product.models import Product  
    from app.modules.auth.services import hash_password

    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        existing_tenant = db.execute(select(Tenant)).scalars().first()
        if existing_tenant is None:
            tenant = Tenant(name="Acme Global Tech", plan="enterprise")
            db.add(tenant)
            db.flush() 

            recruiter = User(
                email="recruiter@company.com",
                hashed_password=hash_password("password123"),
                tenant_id=tenant.id,
                is_active=True,
            )
            db.add(recruiter)
            logger.info(
                "Seeded tenant '%s' and recruiter '%s'.",
                tenant.name,
                recruiter.email,
            )
        else:
            logger.info("Seed skipped: tenant '%s' already present.", existing_tenant.name)
        synced = 0
        for item in CATALOG:
            product = db.execute(
                select(Product).where(Product.sku == item["sku"])
            ).scalars().first()
            if product is None:
                db.add(Product(**item))
                synced += 1
                continue
            changed = False
            for field in ("name", "description", "price", "stock_quantity"):
                if getattr(product, field) != item[field]:
                    setattr(product, field, item[field])
                    changed = True
            if changed:
                synced += 1

        db.commit()
        if synced:
            logger.info("Synced %d boutique catalog product(s).", synced)
        else:
            logger.info("Boutique catalog already up to date (%d products).", len(CATALOG))
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
