package com.example.orderjob;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

@Service
public class OrderProcessor {

    private static final Logger log = LoggerFactory.getLogger(OrderProcessor.class);

    public record Order(String id, String customerId, String product, int quantity) {}

    public record ProcessingResult(String orderId, boolean success, String message) {}

    public void processSampleOrders() {
        List<Order> sampleOrders = Arrays.asList(
            new Order("order-001", "cust-A", "Laptop Pro", 1),
            new Order("order-002", "cust-B", "Wireless Mouse", 3),
            new Order("order-003", "cust-C", "USB-C Hub", 2)
        );

        log.info("Processing {} sample orders", sampleOrders.size());

        for (Order order : sampleOrders) {
            ProcessingResult result = processOrder(order);
            if (result.success()) {
                log.info("✅ Processed order {}: {}", result.orderId(), result.message());
            } else {
                log.error("❌ Failed order {}: {}", result.orderId(), result.message());
            }
        }
    }

    public void processFromQueue(String connectionString) {
        // In a real implementation, use Azure Storage Queue SDK
        // com.azure:azure-storage-queue to dequeue and process messages
        log.info("Would connect to Azure Storage Queue with provided connection string");
        log.info("For this demo, falling back to sample orders");
        processSampleOrders();
    }

    private ProcessingResult processOrder(Order order) {
        try {
            log.info("Processing order {} for customer {} - {} x{}", 
                order.id(), order.customerId(), order.product(), order.quantity());
            
            // Simulate processing time
            Thread.sleep(100);
            
            return new ProcessingResult(order.id(), true, 
                String.format("Processed %d x %s", order.quantity(), order.product()));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return new ProcessingResult(order.id(), false, "Processing interrupted");
        }
    }
}
