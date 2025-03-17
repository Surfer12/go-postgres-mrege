package com.example.userservice.service;

import com.example.grpc.user.*;
import com.example.userservice.model.User;

import io.grpc.ManagedChannel;
import io.grpc.StatusRuntimeException;

import jakarta.persistence.EntityNotFoundException;

import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

/**
 * User service implementation that uses gRPC to communicate with the Mojo database service.
 */
@Service
public class UserServiceImpl extends AbstractGrpcEntityService<User, Integer, UserServiceGrpc.UserServiceBlockingStub> implements UserService {

    @Override
    protected UserServiceGrpc.UserServiceBlockingStub createStub(ManagedChannel channel) {
        return UserServiceGrpc.newBlockingStub(channel);
    }

    @Override
    public User findById(Integer id) {
        try {
            GetUserRequest request = GetUserRequest.newBuilder()
                    .setId(id)
                    .build();
            
            UserResponse response = blockingStub.getUser(request);
            
            if (response.hasUser()) {
                return User.fromProto(response.getUser());
            } else {
                throw new EntityNotFoundException("User not found with id: " + id);
            }
        } catch (StatusRuntimeException e) {
            handleGrpcError(e, id);
            return null; // This line won't be reached due to exception in handleGrpcError
        }
    }

    @Override
    public List<User> findAll(int pageSize, int pageNumber) {
        try {
            ListUsersRequest request = ListUsersRequest.newBuilder()
                    .setPageSize(pageSize)
                    .setPageNumber(pageNumber)
                    .build();
            
            ListUsersResponse response = blockingStub.listUsers(request);
            
            return response.getUsersList().stream()
                    .map(User::fromProto)
                    .collect(Collectors.toList());
        } catch (StatusRuntimeException e) {
            throw new RuntimeException("Failed to list users: " + e.getMessage(), e);
        }
    }

    @Override
    public int getCount() {
        try {
            ListUsersRequest request = ListUsersRequest.newBuilder()
                    .setPageSize(1)
                    .setPageNumber(1)
                    .build();
            
            ListUsersResponse response = blockingStub.listUsers(request);
            return response.getTotalCount();
        } catch (StatusRuntimeException e) {
            throw new RuntimeException("Failed to get user count: " + e.getMessage(), e);
        }
    }

    @Override
    public User create(User user) {
        try {
            if (!user.validate()) {
                throw new IllegalArgumentException("Invalid user data");
            }
            
            CreateUserRequest request = CreateUserRequest.newBuilder()
                    .setUsername(user.getUsername())
                    .setEmail(user.getEmail())
                    .build();
            
            UserResponse response = blockingStub.createUser(request);
            
            if (response.hasUser()) {
                User createdUser = User.fromProto(response.getUser());
                // Preserve additional fields from the original user
                createdUser.setUserType(user.getUserType());
                createdUser.setActive(user.isActive());
                return createdUser;
            } else {
                throw new RuntimeException("Failed to create user: " + response.getErrorMessage());
            }
        } catch (StatusRuntimeException e) {
            throw new RuntimeException("Failed to create user: " + e.getMessage(), e);
        }
    }

    @Override
    public User update(User user) {
        if (user.getId() == null) {
            throw new IllegalArgumentException("User ID cannot be null for update operation");
        }
        
        if (!user.validate()) {
            throw new IllegalArgumentException("Invalid user data");
        }
        
        try {
            UpdateUserRequest request = UpdateUserRequest.newBuilder()
                    .setId(user.getId())
                    .setUsername(user.getUsername())
                    .setEmail(user.getEmail())
                    .build();
            
            UserResponse response = blockingStub.updateUser(request);
            
            if (response.hasUser()) {
                User updatedUser = User.fromProto(response.getUser());
                // Preserve additional fields
                updatedUser.setUserType(user.getUserType());
                updatedUser.setActive(user.isActive());
                return updatedUser;
            } else {
                throw new EntityNotFoundException("User not found with id: " + user.getId());
            }
        } catch (StatusRuntimeException e) {
            handleGrpcError(e, user.getId());
            return null; // This line won't be reached due to exception in handleGrpcError
        }
    }

    @Override
    public boolean delete(Integer id) {
        try {
            DeleteUserRequest request = DeleteUserRequest.newBuilder()
                    .setId(id)
                    .build();
            
            DeleteUserResponse response = blockingStub.deleteUser(request);
            return response.getSuccess();
        } catch (StatusRuntimeException e) {
            String status = e.getStatus().getCode().toString();
            if (status.equals("NOT_FOUND")) {
                return false;
            }
            throw new RuntimeException("Failed to delete user: " + e.getMessage(), e);
        }
    }

    @Override
    public List<User> findByUsername(String usernamePattern) {
        // Since our gRPC service doesn't have this endpoint, we'll fetch all users
        // and filter them in Java. In a production system, we'd add this method to the
        // gRPC service for better performance.
        try {
            ListUsersRequest request = ListUsersRequest.newBuilder()
                    .setPageSize(100) // Fetch a reasonable number
                    .setPageNumber(1)
                    .build();
            
            ListUsersResponse response = blockingStub.listUsers(request);
            
            return response.getUsersList().stream()
                    .map(User::fromProto)
                    .filter(user -> user.getUsername().contains(usernamePattern))
                    .collect(Collectors.toList());
        } catch (StatusRuntimeException e) {
            throw new RuntimeException("Failed to search users by username: " + e.getMessage(), e);
        }
    }

    @Override
    public User findByEmail(String email) {
        // In a production system, we'd add this specific method to the gRPC service
        // For now, we'll filter users on the client side
        try {
            ListUsersRequest request = ListUsersRequest.newBuilder()
                    .setPageSize(100) // Fetch a reasonable number
                    .setPageNumber(1)
                    .build();
            
            ListUsersResponse response = blockingStub.listUsers(request);
            
            return response.getUsersList().stream()
                    .map(User::fromProto)
                    .filter(user -> user.getEmail().equals(email))
                    .findFirst()
                    .orElse(null);
        } catch (StatusRuntimeException e) {
            throw new RuntimeException("Failed to find user by email: " + e.getMessage(), e);
        }
    }

    @Override
    public List<User> findByUserType(User.UserType userType) {
        // Fetch users and filter by type on the client side
        List<User> allUsers = findAll(100, 1);
        
        return allUsers.stream()
                .filter(user -> user.getUserType() == userType)
                .collect(Collectors.toList());
    }

    @Override
    public User updateActiveStatus(Integer userId, boolean active) {
        User user = findById(userId);
        user.setActive(active);
        return update(user);
    }

    @Override
    public User updateUserType(Integer userId, User.UserType userType) {
        User user = findById(userId);
        user.setUserType(userType);
        return update(user);
    }
}