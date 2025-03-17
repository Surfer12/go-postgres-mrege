package com.example.userservice.controller;

import com.example.userservice.model.User;
import com.example.userservice.service.UserService;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for User entity operations.
 * Extends the generic controller with User-specific endpoints.
 */
@RestController
@RequestMapping("/api/users")
public class UserController extends GenericController<User, Integer, UserService> {

    @Autowired
    public UserController(UserService userService) {
        super(userService);
    }

    /**
     * Search users by username
     */
    @GetMapping("/search")
    public ResponseEntity<List<User>> searchByUsername(@RequestParam String username) {
        List<User> users = service.findByUsername(username);
        return ResponseEntity.ok(users);
    }

    /**
     * Find a user by email
     */
    @GetMapping("/by-email")
    public ResponseEntity<User> findByEmail(@RequestParam String email) {
        User user = service.findByEmail(email);
        return ResponseEntity.ok(user);
    }

    /**
     * Find users by type
     */
    @GetMapping("/by-type/{userType}")
    public ResponseEntity<List<User>> findByType(@PathVariable User.UserType userType) {
        List<User> users = service.findByUserType(userType);
        return ResponseEntity.ok(users);
    }

    /**
     * Update user's active status
     */
    @PatchMapping("/{id}/active")
    public ResponseEntity<User> updateActiveStatus(
            @PathVariable Integer id,
            @RequestParam boolean active) {
        
        User user = service.updateActiveStatus(id, active);
        return ResponseEntity.ok(user);
    }

    /**
     * Update user's type
     */
    @PatchMapping("/{id}/type")
    public ResponseEntity<User> updateUserType(
            @PathVariable Integer id,
            @RequestParam User.UserType userType) {
        
        User user = service.updateUserType(id, userType);
        return ResponseEntity.ok(user);
    }
}