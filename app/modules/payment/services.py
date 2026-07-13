"""Internal payment records handler.

Persists transaction outcomes. Kept deliberately thin: the payment route owns
the gateway simulation while this service owns durable record-keeping.
"""

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.payment.models import Payment


def record_payment(
    db: Session,
    *,
    order_id: int,
    amount: Decimal,
    status: str,
    transaction_ref: str | None = None,
) -> Payment:
    payment = Payment(
        order_id=order_id,
        amount=amount,
        status=status,
        transaction_ref=transaction_ref,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return payment


def list_payments(db: Session, order_id: int | None = None) -> list[Payment]:
    stmt = select(Payment).order_by(Payment.id.desc())
    if order_id is not None:
        stmt = stmt.where(Payment.order_id == order_id)
    return list(db.execute(stmt).scalars().all())
