package com.example;

import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class App {
    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

    @GetMapping("/")
    public Map<String, String> home() {
        return Map.of("message", "Hello from Java!", "note", "Built with Jib - no Dockerfile needed!");
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "healthy");
    }
}
