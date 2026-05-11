package com.example.orderjob;

import java.time.Instant;

public record ProcessingResult(String orderId, boolean success, Instant processedAt, String message) {
}
