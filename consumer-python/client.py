import requests


def get_product(base_url: str, product_id: str) -> dict | None:
    response = requests.get(f"{base_url}/products/{product_id}", timeout=5)
    if response.status_code == 404:
        return None
    response.raise_for_status()
    return response.json()
