from fastapi import FastAPI, HTTPException

app = FastAPI(title="backend-b", version="0.1.0")

PRODUCTS = {
    1: {"id": 1, "name": "Keyboard", "price": 100},
    2: {"id": 2, "name": "Mouse", "price": 50},
    3: {"id": 3, "name": "Monitor", "price": 900},
}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "backend-b"}


@app.get("/api/products/{product_id}")
def get_product(product_id: int) -> dict[str, int | str]:
    product = PRODUCTS.get(product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="product not found")

    return product