"""Order domain models: Order and OrderItem.

Note the deliberate absence of SQLAlchemy ForeignKey constraints pointing at
`auth_users` / `product_products`. Those identifiers are stored as plain
integers ("soft references") precisely so this module never joins across
domain boundaries. Referential integrity for cross-domain ids is enforced in
the service layer via the owning module's public API.
"""

from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class OrderStatus(str, Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    CANCELLED = "CANCELLED"


class Order(Base):
    __tablename__ = "order_orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    # Soft references (no cross-domain FK): owned/validated via auth service.
    tenant_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=OrderStatus.PENDING.value
    )
    total_amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )


class OrderItem(Base):
    __tablename__ = "order_order_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    # FK within the SAME domain is allowed.
    order_id: Mapped[int] = mapped_column(
        ForeignKey("order_orders.id"), nullable=False, index=True
    )
    # Soft reference to product domain (no cross-domain FK).
    product_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    price: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)

    order: Mapped["Order"] = relationship(back_populates="items")
