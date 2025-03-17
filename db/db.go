package db

import (
	"database/sql"
	"fmt"
	"my-go-postgres-project/models"

	_ "github.com/lib/pq" // Import the PostgreSQL driver
)

// Database connection parameters (replace with your actual credentials)
const (
	host     = "localhost"
	port     = 5432
	user     = "your_db_user"
	password = "your_db_password"
	dbname   = "your_db_name"
)

// InitDB initializes the database connection and returns a *sql.DB instance.
func InitDB() (*sql.DB, error) {
	connStr := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}

	// Test the connection
	err = db.Ping()
	if err != nil {
		return nil, err
	}

	fmt.Println("Successfully connected to the database!")

	// Create the users table if it doesn't exist
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			username VARCHAR(255) UNIQUE NOT NULL,
			email VARCHAR(255) UNIQUE NOT NULL
		)
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to create users table: %w", err)
	}

	return db, nil
}

// CreateUser creates a new user in the database.
func CreateUser(db *sql.DB, user models.User) (models.User, error) {
	var createdUser models.User
	err := db.QueryRow(`
        INSERT INTO users (username, email)
        VALUES ($1, $2)
        RETURNING id, username, email`, user.Username, user.Email).Scan(&createdUser.ID, &createdUser.Username, &createdUser.Email)

	if err != nil {
		return models.User{}, fmt.Errorf("failed to create user: %w", err)
	}
	return createdUser, nil
}

// GetUserByID retrieves a user from the database by their ID.
func GetUserByID(db *sql.DB, id int) (models.User, error) {
	var user models.User
	err := db.QueryRow("SELECT id, username, email FROM users WHERE id = $1", id).
		Scan(&user.ID, &user.Username, &user.Email)

	if err != nil {
		if err == sql.ErrNoRows {
			return models.User{}, fmt.Errorf("user with ID %d not found", id)
		}
		return models.User{}, fmt.Errorf("failed to get user by ID: %w", err)
	}
	return user, nil
}

// GetAllUsers retrieves all users from the database.
func GetAllUsers(db *sql.DB) ([]models.User, error) {
	rows, err := db.Query("SELECT id, username, email FROM users")
	if err != nil {
		return nil, fmt.Errorf("failed to get all users: %w", err)
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		if err := rows.Scan(&user.ID, &user.Username, &user.Email); err != nil {
			return nil, fmt.Errorf("failed to scan user row: %w", err)
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error during rows iteration: %w", err)
	}

	return users, nil
}

// GetUsers retrieves users with pagination
func GetUsers(db *sql.DB, pageSize int, pageNumber int) ([]models.User, error) {
	offset := (pageNumber - 1) * pageSize
	
	rows, err := db.Query("SELECT id, username, email FROM users ORDER BY id LIMIT $1 OFFSET $2", 
		pageSize, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get users: %w", err)
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var user models.User
		if err := rows.Scan(&user.ID, &user.Username, &user.Email); err != nil {
			return nil, fmt.Errorf("failed to scan user row: %w", err)
		}
		users = append(users, user)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error during rows iteration: %w", err)
	}

	return users, nil
}

// GetUserCount returns the total number of users
func GetUserCount(db *sql.DB) (int, error) {
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM users").Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to get user count: %w", err)
	}
	return count, nil
}

// UpdateUser updates an existing user in the database.
func UpdateUser(db *sql.DB, user models.User) (int64, error) {
	result, err := db.Exec(`
        UPDATE users
        SET username = $1, email = $2
        WHERE id = $3`, user.Username, user.Email, user.ID)

	if err != nil {
		return 0, fmt.Errorf("failed to update user: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return 0, fmt.Errorf("failed to get rows affected: %w", err)
	}
	return rowsAffected, nil
}

// DeleteUser deletes a user from the database by their ID.
func DeleteUser(db *sql.DB, id int) error {
	_, err := db.Exec("DELETE FROM users WHERE id = $1", id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}
	return nil
}
