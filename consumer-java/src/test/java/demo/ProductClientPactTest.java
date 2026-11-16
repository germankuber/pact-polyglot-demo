package demo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import au.com.dius.pact.consumer.MockServer;
import au.com.dius.pact.consumer.dsl.LambdaDsl;
import au.com.dius.pact.consumer.dsl.PactDslWithProvider;
import au.com.dius.pact.consumer.junit5.PactConsumerTestExt;
import au.com.dius.pact.consumer.junit5.PactTestFor;
import au.com.dius.pact.core.model.PactSpecVersion;
import au.com.dius.pact.core.model.V4Pact;
import au.com.dius.pact.core.model.annotations.Pact;
import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

@ExtendWith(PactConsumerTestExt.class)
@PactTestFor(providerName = "product-service", pactVersion = PactSpecVersion.V4)
class ProductClientPactTest {

    @Pact(consumer = "java-billing")
    V4Pact productExists(PactDslWithProvider builder) {
        return builder
                .given("product 1 exists")
                .uponReceiving("a request for product 1")
                .path("/products/1")
                .method("GET")
                .willRespondWith()
                .status(200)
                .headers(Map.of("Content-Type", "application/json"))
                .body(LambdaDsl.newJsonBody(body -> body
                        .stringValue("id", "1")
                        .stringType("name", "Laptop")
                        .decimalType("price", 999.99)).build())
                .toPact(V4Pact.class);
    }

    @Pact(consumer = "java-billing")
    V4Pact productNotFound(PactDslWithProvider builder) {
        return builder
                .given("product 99 does not exist")
                .uponReceiving("a request for product 99")
                .path("/products/99")
                .method("GET")
                .willRespondWith()
                .status(404)
                .toPact(V4Pact.class);
    }

    @Test
    @PactTestFor(pactMethod = "productExists")
    void returnsProductThatExists(MockServer mockServer) throws Exception {
        JsonNode product = new ProductClient(mockServer.getUrl()).getProduct("1").orElseThrow();
        assertEquals("1", product.get("id").asText());
        assertEquals("Laptop", product.get("name").asText());
        assertEquals(999.99, product.get("price").asDouble());
    }

    @Test
    @PactTestFor(pactMethod = "productNotFound")
    void returnsEmptyWhenProductDoesNotExist(MockServer mockServer) throws Exception {
        assertTrue(new ProductClient(mockServer.getUrl()).getProduct("99").isEmpty());
    }
}
