package com.example.orderjob;

public record Order(String id, String customerId, String product, int quantity) {
}
