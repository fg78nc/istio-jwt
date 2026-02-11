package com.example.istiojwt.controller;

import com.example.istiojwt.model.UserInfo;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Base64;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @GetMapping("/public")
    public ResponseEntity<Map<String, String>> publicEndpoint() {
        return ResponseEntity.ok(Map.of("message", "This is a public endpoint - no authentication required"));
    }

    @GetMapping("/secured")
    public ResponseEntity<UserInfo> hello(
            @RequestHeader(value = "X-Jwt-Payload", required = false) String jwtPayload) {
        if (jwtPayload == null || jwtPayload.isBlank()) {
            return ResponseEntity.ok(new UserInfo("unknown", "unknown", "unknown",
                    "Hello! No JWT payload header found."));
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(jwtPayload);
            JsonNode claims = objectMapper.readTree(decoded);
            String sub = claims.has("sub") ? claims.get("sub").asText() : "unknown";
            String iss = claims.has("iss") ? claims.get("iss").asText() : "unknown";
            String role = claims.has("role") ? claims.get("role").asText() : "none";
            return ResponseEntity.ok(new UserInfo(sub, iss, role,
                    "Hello, " + sub + "! Authenticated via Istio JWT."));
        } catch (Exception e) {
            return ResponseEntity.ok(new UserInfo("unknown", "unknown", "unknown",
                    "Hello! Could not parse JWT payload: " + e.getMessage()));
        }
    }

    @GetMapping("/admin")
    public ResponseEntity<UserInfo> admin(
            @RequestHeader(value = "X-Jwt-Payload", required = false) String jwtPayload) {
        if (jwtPayload == null || jwtPayload.isBlank()) {
            return ResponseEntity.ok(new UserInfo("unknown", "unknown", "unknown",
                    "Admin endpoint reached, but no JWT payload header found."));
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(jwtPayload);
            JsonNode claims = objectMapper.readTree(decoded);
            String sub = claims.has("sub") ? claims.get("sub").asText() : "unknown";
            String iss = claims.has("iss") ? claims.get("iss").asText() : "unknown";
            String role = claims.has("role") ? claims.get("role").asText() : "none";
            return ResponseEntity.ok(new UserInfo(sub, iss, role,
                    "Welcome to the admin area, " + sub + "!"));
        } catch (Exception e) {
            return ResponseEntity.ok(new UserInfo("unknown", "unknown", "unknown",
                    "Admin endpoint reached, but could not parse JWT payload: " + e.getMessage()));
        }
    }
}
