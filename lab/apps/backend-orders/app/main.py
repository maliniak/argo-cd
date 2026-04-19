import os

import requests
from fastapi import FastAPI, HTTPException

app = FastAPI(title="backend-orders", version="0.1.0")

BACKEND_PRODUCTS_URL = os.getenv("BACKEND_PRODUCTS_URL", "http://backend-products.demo.svc.cluster.local:8000")

ORDERS = {
    101: {"order_id": 101, "product_id": 1, "quantity": 2},
    102: {"order_id": 102, "product_id": 3, "quantity": 1},
}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "backend-orders"}


@app.get("/api/orders")
def list_orders() -> list[dict[str, int]]:
    return [
        {"order_id": order["order_id"], "product_id": order["product_id"]}
        for order in ORDERS.values()
    ]


@app.get("/api/orders/{order_id}")
def get_order(order_id: int) -> dict[str, int | dict[str, int | str]]:
    order = ORDERS.get(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")

    try:
        product_response = requests.get(
            f"{BACKEND_PRODUCTS_URL}/api/products/{order['product_id']}",
            timeout=5,
        )
        product_response.raise_for_status()
    except requests.RequestException as error:
        raise HTTPException(status_code=502, detail=f"backend-products request failed: {error}") from error

    return {
        "order_id": order["order_id"],
        "quantity": order["quantity"],
        "product": product_response.json(),
    }