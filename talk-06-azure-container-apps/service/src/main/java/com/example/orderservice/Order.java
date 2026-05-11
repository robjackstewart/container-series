package com.example.orderservice;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonValue;
import java.time.Instant;
import java.util.UUID;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class Order {

    @JsonProperty("id")
    private UUID id;

    @JsonProperty("customerId")
    private String customerId;

    @JsonProperty("product")
    private String product;

    @JsonProperty("quantity")
    private int quantity;

    @JsonProperty("status")
    @JsonFormat(shape = JsonFormat.Shape.STRING)
    private Status status;

    @JsonProperty("createdAt")
    @JsonFormat(shape = JsonFormat.Shape.STRING)
    private Instant createdAt;

    public Order() {
    }

    public Order(UUID id, String customerId, String product, int quantity, Status status, Instant createdAt) {
        this.id = id;
        this.customerId = customerId;
        this.product = product;
        this.quantity = quantity;
        this.status = status;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getCustomerId() {
        return customerId;
    }

    public void setCustomerId(String customerId) {
        this.customerId = customerId;
    }

    public String getProduct() {
        return product;
    }

    public void setProduct(String product) {
        this.product = product;
    }

    public int getQuantity() {
        return quantity;
    }

    public void setQuantity(int quantity) {
        this.quantity = quantity;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public enum Status {
        PENDING,
        PROCESSING,
        COMPLETED;

        @JsonCreator
        public static Status fromValue(String value) {
            if (value == null || value.isBlank()) {
                return null;
            }
            return Status.valueOf(value.trim().toUpperCase());
        }

        @JsonValue
        public String toValue() {
            return name();
        }
    }
}
