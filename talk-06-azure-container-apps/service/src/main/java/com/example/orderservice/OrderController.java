package com.example.orderservice;

import com.example.orderservice.Order.Status;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping
public class OrderController {

    private static final Logger log = LoggerFactory.getLogger(OrderController.class);

    private final ConcurrentHashMap<UUID, Order> orders = new ConcurrentHashMap<>();
    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper;
    private final boolean daprEnabled;
    private final String daprHttpPort;
    private final String daprStateStoreName;

    public OrderController(@Value("${app.dapr.enabled:false}") boolean daprEnabled, ObjectMapper objectMapper) {
        this.daprEnabled = daprEnabled;
        this.objectMapper = objectMapper;
        this.daprHttpPort = System.getenv().getOrDefault("DAPR_HTTP_PORT", "3500");
        this.daprStateStoreName = System.getenv().getOrDefault("DAPR_STATE_STORE_NAME", "statestore");
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
            "status", "UP",
            "service", "order-service",
            "ordersInMemory", orders.size(),
            "daprEnabled", daprEnabled,
            "daprHttpPort", daprHttpPort
        );
    }

    @GetMapping("/orders")
    public List<Order> getOrders() {
        return orders.values().stream()
            .sorted(Comparator.comparing(Order::getCreatedAt))
            .toList();
    }

    @PostMapping("/orders")
    public ResponseEntity<Order> createOrder(@RequestBody Order request) {
        validateNewOrder(request);

        Order order = new Order(
            UUID.randomUUID(),
            request.getCustomerId(),
            request.getProduct(),
            request.getQuantity(),
            Status.PENDING,
            Instant.now()
        );

        orders.put(order.getId(), order);
        persistToDaprStateStore(order);
        log.info("Created order {} for customer {}", order.getId(), order.getCustomerId());

        return ResponseEntity.status(HttpStatus.CREATED).body(order);
    }

    @GetMapping("/orders/{id}")
    public Order getOrder(@PathVariable UUID id) {
        return findOrder(id);
    }

    @PutMapping("/orders/{id}/status")
    public Order updateStatus(@PathVariable UUID id, @RequestBody StatusUpdateRequest request) {
        if (request == null || request.status() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "status is required");
        }

        Order updatedOrder = orders.compute(id, (orderId, existingOrder) -> {
            if (existingOrder == null) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "order not found");
            }
            existingOrder.setStatus(request.status());
            return existingOrder;
        });

        persistToDaprStateStore(updatedOrder);
        log.info("Updated order {} to status {}", id, request.status());
        return updatedOrder;
    }

    private void validateNewOrder(Order request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "order body is required");
        }
        if (request.getCustomerId() == null || request.getCustomerId().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "customerId is required");
        }
        if (request.getProduct() == null || request.getProduct().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "product is required");
        }
        if (request.getQuantity() <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "quantity must be greater than zero");
        }
    }

    private Order findOrder(UUID id) {
        Order order = orders.get(id);
        if (order == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "order not found");
        }
        return order;
    }

    private void persistToDaprStateStore(Order order) {
        if (!daprEnabled) {
            return;
        }

        try {
            String body = objectMapper.writeValueAsString(List.of(Map.of(
                "key", "order-" + order.getId(),
                "value", order
            )));

            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://127.0.0.1:" + daprHttpPort + "/v1.0/state/" + daprStateStoreName))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() >= 400) {
                log.warn("Dapr state store returned status {} for order {} with body {}",
                    response.statusCode(), order.getId(), response.body());
            } else {
                log.info("Persisted order {} to Dapr state store", order.getId());
            }
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialize order {} for Dapr state store", order.getId(), e);
        } catch (IOException | InterruptedException e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            log.warn("Failed to persist order {} to Dapr state store", order.getId(), e);
        }
    }

    public record StatusUpdateRequest(Status status) {
    }
}
