import path from "node:path";
import { describe, expect, it } from "vitest";
import { PactV4, MatchersV3 } from "@pact-foundation/pact";
import { getProduct } from "../src/client";

const { like, decimal } = MatchersV3;

const expectDiscount = process.env.EXPECT_DISCOUNT === "true";

const pact = new PactV4({
  consumer: "ts-web",
  provider: "product-service",
  dir: path.resolve(__dirname, "../../pacts"),
});

describe("product-service contract", () => {
  it("returns a product that exists", async () => {
    await pact
      .addInteraction()
      .given("product 1 exists")
      .uponReceiving("a request for product 1")
      .withRequest("GET", "/products/1")
      .willRespondWith(200, (builder) => {
        builder.headers({ "Content-Type": "application/json" });
        builder.jsonBody({
          id: "1",
          name: like("Laptop"),
          price: decimal(999.99),
          ...(expectDiscount ? { discount: decimal(0.1) } : {}),
        });
      })
      .executeTest(async (mockServer) => {
        const product = await getProduct(mockServer.url, "1");
        expect(product).toMatchObject({ id: "1", name: "Laptop", price: 999.99 });
      });
  });

  it("returns null when the product does not exist", async () => {
    await pact
      .addInteraction()
      .given("product 99 does not exist")
      .uponReceiving("a request for product 99")
      .withRequest("GET", "/products/99")
      .willRespondWith(404)
      .executeTest(async (mockServer) => {
        expect(await getProduct(mockServer.url, "99")).toBeNull();
      });
  });
});
