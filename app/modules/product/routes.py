"""Public, unauthenticated product catalog endpoints."""

from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.product import services

router = APIRouter()


class ProductResponse(BaseModel):
    id: int
    name: str
    description: str | None = None
    sku: str
    price: Decimal
    stock_quantity: int

    model_config = {"from_attributes": True}


@router.get("", response_model=list[ProductResponse], tags=["products"])
async def list_products(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
) -> list[ProductResponse]:
    """Public catalog listing so reviewers can browse without logging in."""
    return services.list_products(db, skip=skip, limit=limit)


@router.get("/{product_id}", response_model=ProductResponse, tags=["products"])
async def get_product(
    product_id: int,
    db: Session = Depends(get_db),
) -> ProductResponse:
    product = services.get_product(db, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product {product_id} not found",
        )
    return product
