package com.example.userservice.model;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Builder;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * User entity representing a system user
 */
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class User extends AbstractEntity<Integer, User> {
    
    /**
     * User types for different access levels and permissions
     */
    public enum UserType {
        STANDARD,
        ADMIN,
        GUEST
    }
    
    @NotBlank(message = "Username is required")
    private String username;
    
    @NotBlank(message = "Email is required")
    @Email(message = "Email should be valid")
    private String email;
    
    private UserType userType = UserType.STANDARD;
    private boolean active = true;
    
    @Builder
    public User(Integer id, String username, String email, UserType userType, boolean active) {
        super(id);
        this.username = username;
        this.email = email;
        this.userType = userType != null ? userType : UserType.STANDARD;
        this.active = active;
    }
    
    /**
     * Convert from gRPC generated User object to domain User
     */
    public static User fromProto(com.example.grpc.user.User protoUser) {
        return User.builder()
                .id(protoUser.getId())
                .username(protoUser.getUsername())
                .email(protoUser.getEmail())
                .active(true) // Default value since proto doesn't have these fields
                .userType(UserType.STANDARD)
                .build();
    }
    
    /**
     * Convert to gRPC User object
     */
    public com.example.grpc.user.User toProto() {
        return com.example.grpc.user.User.newBuilder()
                .setId(id != null ? id : 0)
                .setUsername(username)
                .setEmail(email)
                .build();
    }
    
    @Override
    public boolean validate() {
        // Basic validation from annotations is performed by bean validation
        // Additional business logic validation
        if (username != null && username.length() < 3) {
            return false; // Username too short
        }
        
        if (email != null && !email.contains("@")) {
            return false; // Simple email format validation
        }
        
        return true;
    }
    
    @Override
    @SuppressWarnings("unchecked")
    public <D> D toDto() {
        // Default implementation returns the gRPC User
        return (D) toProto();
    }
    
    @Override
    public User withId(Integer id) {
        return User.builder()
                .id(id)
                .username(this.username)
                .email(this.email)
                .userType(this.userType)
                .active(this.active)
                .build();
    }
    
    @Override
    public User copy() {
        return User.builder()
                .id(this.id)
                .username(this.username)
                .email(this.email)
                .userType(this.userType)
                .active(this.active)
                .build();
    }
    
    /**
     * Check if user has admin privileges
     */
    public boolean isAdmin() {
        return UserType.ADMIN.equals(userType);
    }
}