"""Product/inventory lookup logic.

This is the public Python API other modules (e.g. order) call to resolve
product facts. Cross-domain callers MUST use these functions rather than
joining product tables directly.
"""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.product.models import Product


def list_products(db: Session, skip: int = 0, limit: int = 100) -> list[Product]:
    stmt = select(Product).offset(skip).limit(limit).order_by(Product.id)
    return list(db.execute(stmt).scalars().all())


def get_product(db: Session, product_id: int) -> Product | None:
    return db.get(Product, product_id)


def get_products_by_ids(db: Session, product_ids: list[int]) -> dict[int, Product]:
    """Bulk-resolve products keyed by id (used by order placement)."""
    if not product_ids:
        return {}
    stmt = select(Product).where(Product.id.in_(product_ids))
    rows = db.execute(stmt).scalars().all()
    return {p.id: p for p in rows}


def decrement_stock(db: Session, product_id: int, quantity: int) -> Product | None:
    """Atomically reduce stock for a product within the caller's transaction."""
    product = db.get(Product, product_id)
    if product is None:
        return None
    if product.stock_quantity < quantity:
        return None
    product.stock_quantity -= quantity
    db.flush()
    return product
