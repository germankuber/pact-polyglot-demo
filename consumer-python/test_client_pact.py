from pathlib import Path

import pytest
from pact import Pact, match

from client import get_product

PACTS_DIR = Path(__file__).resolve().parent.parent / "pacts"


@pytest.fixture(scope="module")
def base_url():
    pact = Pact("python-reports", "product-service").with_specification("V4")
    (
        pact.upon_receiving("a request for product 1")
        .given("product 1 exists")
        .with_request("GET", "/products/1")
        .will_respond_with(200)
        .with_header("Content-Type", "application/json")
        .with_body(
            {
                "id": "1",
                "name": match.str("Laptop"),
                "price": match.decimal(999.99),
            },
            content_type="application/json",
        )
    )
    (
        pact.upon_receiving("a request for product 99")
        .given("product 99 does not exist")
        .with_request("GET", "/products/99")
        .will_respond_with(404)
    )
    with pact.serve() as server:
        yield str(server.url).rstrip("/")
    pact.write_file(PACTS_DIR, overwrite=True)


def test_product_exists(base_url):
    product = get_product(base_url, "1")
    assert product == {"id": "1", "name": "Laptop", "price": 999.99}


def test_product_not_found(base_url):
    assert get_product(base_url, "99") is None
