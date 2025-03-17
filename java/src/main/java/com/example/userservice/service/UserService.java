package com.example.userservice.service;

import com.example.userservice.model.User;

import java.util.List;

/**
 * Service interface for User entity operations.
 * Extends the generic EntityService with User-specific operations.
 */
public interface UserService extends EntityService<User, Integer> {
    
    /**
     * Find users by username pattern
     * 
     * @param usernamePattern pattern to search for
     * @return list of matching users
     */
    List<User> findByUsername(String usernamePattern);
    
    /**
     * Find users by exact email address
     * 
     * @param email the email to search for
     * @return the user with the specified email, or null if not found
     */
    User findByEmail(String email);
    
    /**
     * Find users by type
     * 
     * @param userType the user type to search for
     * @return list of users with the specified type
     */
    List<User> findByUserType(User.UserType userType);
    
    /**
     * Change a user's active status
     * 
     * @param userId the user ID
     * @param active the new active status
     * @return the updated user
     */
    User updateActiveStatus(Integer userId, boolean active);
    
    /**
     * Change a user's type
     * 
     * @param userId the user ID
     * @param userType the new user type
     * @return the updated user
     */
    User updateUserType(Integer userId, User.UserType userType);
}