package com.example.istiojwt.model;

public record UserInfo(String sub, String issuer, String role, String message) {
}
