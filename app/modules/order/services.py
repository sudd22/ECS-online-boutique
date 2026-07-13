"""Order placement logic.

Cross-domain rule: product facts are resolved through the product module's
public service API (`product.services`), never via a SQL join. The acting user
/ tenant identity arrives pre-resolved from the auth dependency.
"""

from decimal import Decimal

from sqlalchemy.orm import Session

from app.modules.order.models import Order, OrderItem, OrderStatus
from app.modules.product import services as product_services


class OrderError(Exception):
    """Domain-level error surfaced to the route as a 4xx response."""

    def __init__(self, message: str, status_code: int = 400) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def create_order(
    db: Session,
    *,
    tenant_id: int,
    user_id: int,
    items: list[dict],
) -> Order:
    """Create a PENDING order.

    `items` is a list of {"product_id": int, "quantity": int}. Prices and
    stock are validated through the product service (no cross-module join).
    """
    if not items:
        raise OrderError("An order must contain at least one item.")

    product_ids = [item["product_id"] for item in items]
    catalog = product_services.get_products_by_ids(db, product_ids)

    order = Order(
        tenant_id=tenant_id,
        user_id=user_id,
        status=OrderStatus.PENDING.value,
        total_amount=Decimal("0.00"),
    )

    total = Decimal("0.00")
    for item in items:
        product_id = item["product_id"]
        quantity = int(item["quantity"])

        if quantity <= 0:
            raise OrderError(f"Quantity for product {product_id} must be positive.")

        product = catalog.get(product_id)
        if product is None:
            raise OrderError(f"Product {product_id} does not exist.", status_code=404)

        if product.stock_quantity < quantity:
            raise OrderError(
                f"Insufficient stock for product {product_id} "
                f"(requested {quantity}, available {product.stock_quantity}).",
                status_code=409,
            )

        # Reserve stock through the product module's public API.
        product_services.decrement_stock(db, product_id, quantity)

        line_price = Decimal(str(product.price))
        total += line_price * quantity
        order.items.append(
            OrderItem(
                product_id=product_id,
                quantity=quantity,
                price=line_price,
            )
        )

    order.total_amount = total
    db.add(order)
    db.commit()
    db.refresh(order)
    return order


def get_order(db: Session, order_id: int, tenant_id: int) -> Order | None:
    order = db.get(Order, order_id)
    if order is None or order.tenant_id != tenant_id:
        return None
    return order


def list_orders_for_tenant(db: Session, tenant_id: int) -> list[Order]:
    from sqlalchemy import select

    stmt = select(Order).where(Order.tenant_id == tenant_id).order_by(Order.id.desc())
    return list(db.execute(stmt).scalars().all())


def mark_order_paid(db: Session, order_id: int) -> Order | None:
    order = db.get(Order, order_id)
    if order is None:
        return None
    order.status = OrderStatus.PAID.value
    db.commit()
    db.refresh(order)
    return order
