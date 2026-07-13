"""Order endpoints. Protected by the shared get_current_user guard."""

from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.auth.models import User
from app.modules.order import services
from app.modules.order.services import OrderError

router = APIRouter()


class OrderItemInput(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class CreateOrderRequest(BaseModel):
    items: list[OrderItemInput]


class OrderItemResponse(BaseModel):
    product_id: int
    quantity: int
    price: Decimal

    model_config = {"from_attributes": True}


class OrderResponse(BaseModel):
    id: int
    tenant_id: int
    user_id: int
    status: str
    total_amount: Decimal
    items: list[OrderItemResponse]

    model_config = {"from_attributes": True}


@router.post(
    "",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["orders"],
)
async def create_order(
    payload: CreateOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrderResponse:
    """Create a PENDING order for the authenticated user's tenant."""
    try:
        order = services.create_order(
            db,
            tenant_id=current_user.tenant_id,
            user_id=current_user.id,
            items=[item.model_dump() for item in payload.items],
        )
    except OrderError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message)
    return order


@router.get("", response_model=list[OrderResponse], tags=["orders"])
async def list_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[OrderResponse]:
    return services.list_orders_for_tenant(db, current_user.tenant_id)


@router.get("/{order_id}", response_model=OrderResponse, tags=["orders"])
async def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> OrderResponse:
    order = services.get_order(db, order_id, current_user.tenant_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order {order_id} not found",
        )
    return order
