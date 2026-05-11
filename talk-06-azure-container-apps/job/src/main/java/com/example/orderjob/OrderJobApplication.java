package com.example.orderjob;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@SpringBootApplication
public class OrderJobApplication {

    private static final Logger log = LoggerFactory.getLogger(OrderJobApplication.class);

    public static void main(String[] args) {
        int exitCode = SpringApplication.exit(SpringApplication.run(OrderJobApplication.class, args));
        System.exit(exitCode);
    }

    @Bean
    CommandLineRunner run(OrderProcessor processor) {
        return args -> {
            log.info("=== Order Processor Job Starting ===");
            log.info("Environment: {}", System.getenv().getOrDefault("ENVIRONMENT", "development"));

            String connectionString = System.getenv("AZURE_STORAGE_CONNECTION_STRING");

            if (connectionString != null && !connectionString.isBlank()) {
                log.info("Azure Storage Queue connection found - processing real queue");
                processor.processFromQueue(connectionString);
            } else {
                log.info("No Azure Storage Queue connection - processing sample orders");
                processor.processSampleOrders();
            }

            log.info("=== Order Processor Job Complete ===");
        };
    }
}
