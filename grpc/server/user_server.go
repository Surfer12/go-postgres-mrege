package server

import (
	"context"
	"database/sql"
	"fmt"
	
	"my-go-postgres-project/db"
	"my-go-postgres-project/models"
	pb "my-go-postgres-project/proto"
	
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// UserServiceServer implements the gRPC UserService
type UserServiceServer struct {
	pb.UnimplementedUserServiceServer
	DB *sql.DB
}

// NewUserServiceServer creates a new UserServiceServer with the given DB connection
func NewUserServiceServer(db *sql.DB) *UserServiceServer {
	return &UserServiceServer{DB: db}
}

// GetUser retrieves a user by ID
func (s *UserServiceServer) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.UserResponse, error) {
	// Get the user from the database
	user, err := db.GetUserByID(s.DB, int(req.Id))
	if err != nil {
		if err == sql.ErrNoRows {
			return &pb.UserResponse{
				ErrorMessage: fmt.Sprintf("User with ID %d not found", req.Id),
			}, status.Error(codes.NotFound, "user not found")
		}
		return &pb.UserResponse{
			ErrorMessage: "Internal server error",
		}, status.Error(codes.Internal, err.Error())
	}

	// Convert the model to protobuf message
	return &pb.UserResponse{
		User: &pb.User{
			Id:       int32(user.ID),
			Username: user.Username,
			Email:    user.Email,
		},
	}, nil
}

// ListUsers retrieves all users with optional pagination
func (s *UserServiceServer) ListUsers(ctx context.Context, req *pb.ListUsersRequest) (*pb.ListUsersResponse, error) {
	// Set default pagination if not provided
	pageSize := 10
	pageNumber := 1
	
	if req.PageSize > 0 {
		pageSize = int(req.PageSize)
	}
	
	if req.PageNumber > 0 {
		pageNumber = int(req.PageNumber)
	}
	
	// Get users from the database
	users, err := db.GetUsers(s.DB, pageSize, pageNumber)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	
	// Get total count
	totalCount, err := db.GetUserCount(s.DB)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	
	// Convert the models to protobuf messages
	pbUsers := make([]*pb.User, len(users))
	for i, user := range users {
		pbUsers[i] = &pb.User{
			Id:       int32(user.ID),
			Username: user.Username,
			Email:    user.Email,
		}
	}
	
	return &pb.ListUsersResponse{
		Users:      pbUsers,
		TotalCount: int32(totalCount),
	}, nil
}

// CreateUser creates a new user
func (s *UserServiceServer) CreateUser(ctx context.Context, req *pb.CreateUserRequest) (*pb.UserResponse, error) {
	// Create user object
	user := models.User{
		Username: req.Username,
		Email:    req.Email,
	}
	
	// Insert into database
	id, err := db.CreateUser(s.DB, user)
	if err != nil {
		return &pb.UserResponse{
			ErrorMessage: "Failed to create user",
		}, status.Error(codes.Internal, err.Error())
	}
	
	// Return the created user with ID
	return &pb.UserResponse{
		User: &pb.User{
			Id:       int32(id),
			Username: user.Username,
			Email:    user.Email,
		},
	}, nil
}

// UpdateUser updates an existing user
func (s *UserServiceServer) UpdateUser(ctx context.Context, req *pb.UpdateUserRequest) (*pb.UserResponse, error) {
	// Create user object
	user := models.User{
		ID:       int(req.Id),
		Username: req.Username,
		Email:    req.Email,
	}
	
	// Update in database
	err := db.UpdateUser(s.DB, user)
	if err != nil {
		if err == sql.ErrNoRows {
			return &pb.UserResponse{
				ErrorMessage: fmt.Sprintf("User with ID %d not found", req.Id),
			}, status.Error(codes.NotFound, "user not found")
		}
		return &pb.UserResponse{
			ErrorMessage: "Failed to update user",
		}, status.Error(codes.Internal, err.Error())
	}
	
	// Return the updated user
	return &pb.UserResponse{
		User: &pb.User{
			Id:       int32(user.ID),
			Username: user.Username,
			Email:    user.Email,
		},
	}, nil
}

// DeleteUser deletes a user by ID
func (s *UserServiceServer) DeleteUser(ctx context.Context, req *pb.DeleteUserRequest) (*pb.DeleteUserResponse, error) {
	// Delete from database
	err := db.DeleteUser(s.DB, int(req.Id))
	if err != nil {
		if err == sql.ErrNoRows {
			return &pb.DeleteUserResponse{
				Success: false,
				Message: fmt.Sprintf("User with ID %d not found", req.Id),
			}, status.Error(codes.NotFound, "user not found")
		}
		return &pb.DeleteUserResponse{
			Success: false,
			Message: "Failed to delete user",
		}, status.Error(codes.Internal, err.Error())
	}
	
	// Return success
	return &pb.DeleteUserResponse{
		Success: true,
		Message: fmt.Sprintf("User with ID %d successfully deleted", req.Id),
	}, nil
}