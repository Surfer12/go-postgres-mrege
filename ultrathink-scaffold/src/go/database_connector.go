package db

import (
	"database/sql"
	"fmt"
	"sync"

	// Import the PostgreSQL driver silently
	_ "github.com/lib/pq"
)

// Mock interop functions that would normally be provided by the Magic library
// In a real implementation, these would come from an imported package
var interop = struct {
	RegisterFinalizer  func(obj interface{}, finalizer func(interface{}))
	CreateConnHandle   func(connector interface{}) uint64
	FreeHandle         func(handle uint64) error
	CreateResultHandle func(result interface{}) uint64
	CreateUserHandle   func(id int, username string, email string) uint64
	ExtractUserData    func(handle uint64) (userData struct {
		ID              int
		Username, Email string
	}, err error)
}{
	RegisterFinalizer: func(obj interface{}, finalizer func(interface{})) {
		// In a real implementation, this would register a finalizer
		// For now, it's just a mock
	},
	CreateConnHandle: func(connector interface{}) uint64 {
		// Mock implementation
		return 1
	},
	FreeHandle: func(handle uint64) error {
		// Mock implementation
		return nil
	},
	CreateResultHandle: func(result interface{}) uint64 {
		// Mock implementation
		return 2
	},
	CreateUserHandle: func(id int, username string, email string) uint64 {
		// Mock implementation
		return 3
	},
	ExtractUserData: func(handle uint64) (userData struct {
		ID              int
		Username, Email string
	}, err error) {
		// Mock implementation
		return struct {
			ID              int
			Username, Email string
		}{0, "", ""}, nil
	},
}

// DBConnector provides a memory-safe database connector with interoperability
// Follows the same safety patterns as other language implementations
type DBConnector struct {
	connectionString string
	isConnected      bool
	db               *sql.DB
	mutex            sync.Mutex
	// Uses a handle instead of raw pointers for cross-language interop
	connHandle uint64
}

// NewDBConnector creates a new database connector with the given connection string
// Uses automatic resource management for memory safety
func NewDBConnector(connectionString string) *DBConnector {
	connector := &DBConnector{
		connectionString: connectionString,
		isConnected:      false,
	}

	// Register with the finalizer to ensure cleanup even if Close() isn't called
	// This prevents memory leaks without requiring manual memory management
	interop.RegisterFinalizer(connector, func(obj interface{}) {
		c := obj.(*DBConnector)
		if c.isConnected {
			c.Close()
		}
	})

	return connector
}

// Connect establishes a connection to the database
func (c *DBConnector) Connect() error {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	if c.isConnected {
		return nil
	}

	var err error
	c.db, err = sql.Open("postgres", c.connectionString)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Test the connection
	err = c.db.Ping()
	if err != nil {
		c.db.Close() // Clean up safely in case of error
		return fmt.Errorf("failed to ping database: %w", err)
	}

	c.isConnected = true

	// Create a handle for interop with other languages
	c.connHandle = interop.CreateConnHandle(c)

	return nil
}

// Close safely closes the database connection
// This is automatically called by the finalizer if not called manually
func (c *DBConnector) Close() error {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	if !c.isConnected {
		return nil
	}

	// Free the interop handle
	if c.connHandle != 0 {
		interop.FreeHandle(c.connHandle)
		c.connHandle = 0
	}

	// Close the database connection
	err := c.db.Close()
	c.isConnected = false

	return err
}

// Query executes a query and returns a memory-safe result
// Memory management is automated to prevent leaks
func (c *DBConnector) Query(query string, args ...interface{}) (*Result, error) {
	c.mutex.Lock()
	defer c.mutex.Unlock()

	if !c.isConnected {
		return nil, fmt.Errorf("not connected to database")
	}

	rows, err := c.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}

	// Create a safe wrapper around the rows
	// Result handles its own memory management
	return NewResult(rows), nil
}

// Result is a memory-safe wrapper around sql.Rows
type Result struct {
	rows       *sql.Rows
	resultData [][]string
	columns    []string
	closed     bool
	mutex      sync.Mutex
}

// NewResult creates a new result from sql.Rows
// Automatically manages the lifecycle of the rows
func NewResult(rows *sql.Rows) *Result {
	result := &Result{
		rows:   rows,
		closed: false,
	}

	// Register finalizer for safety
	interop.RegisterFinalizer(result, func(obj interface{}) {
		r := obj.(*Result)
		if !r.closed {
			r.Close()
		}
	})

	// Cache the results to prevent use-after-free issues
	result.cacheResults()

	return result
}

// cacheResults reads all data from rows into memory
// This prevents use-after-free issues when passing data between languages
func (r *Result) cacheResults() {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	// Get column names
	var err error
	r.columns, err = r.rows.Columns()
	if err != nil {
		r.columns = []string{}
		return
	}

	// Read all rows into memory
	r.resultData = [][]string{}

	for r.rows.Next() {
		// Create a slice of interface{} to hold the values
		values := make([]interface{}, len(r.columns))
		valuePtrs := make([]interface{}, len(r.columns))

		// Assign pointers to each element
		for i := range values {
			valuePtrs[i] = &values[i]
		}

		// Scan the row into the pointer slice
		if err := r.rows.Scan(valuePtrs...); err != nil {
			continue
		}

		// Convert values to strings
		stringValues := make([]string, len(r.columns))
		for i, val := range values {
			if val == nil {
				stringValues[i] = ""
			} else {
				stringValues[i] = fmt.Sprintf("%v", val)
			}
		}

		r.resultData = append(r.resultData, stringValues)
	}

	// Close rows immediately after caching
	r.rows.Close()
}

// GetRowCount returns the number of rows in the result
func (r *Result) GetRowCount() int {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	return len(r.resultData)
}

// GetColumnCount returns the number of columns in the result
func (r *Result) GetColumnCount() int {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	return len(r.columns)
}

// GetColumnNames returns the column names in the result
func (r *Result) GetColumnNames() []string {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	return r.columns
}

// GetValue safely retrieves a value at the specified row and column
func (r *Result) GetValue(row, column int) (string, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if row < 0 || row >= len(r.resultData) {
		return "", fmt.Errorf("row index out of bounds")
	}

	if column < 0 || column >= len(r.columns) {
		return "", fmt.Errorf("column index out of bounds")
	}

	return r.resultData[row][column], nil
}

// Close releases any resources used by the Result
func (r *Result) Close() {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if !r.closed {
		if r.rows != nil {
			r.rows.Close()
		}
		r.closed = true
	}
}

// GetHandle returns a handle for interop with other languages
func (r *Result) GetHandle() uint64 {
	return interop.CreateResultHandle(r)
}

// User represents a user entity with memory-safe operations
type User struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	Email    string `json:"email"`
}

// NewUserFromHandle creates a User from an interop handle
func NewUserFromHandle(handle uint64) (*User, error) {
	userData, err := interop.ExtractUserData(handle)
	if err != nil {
		return nil, err
	}

	return &User{
		ID:       userData.ID,
		Username: userData.Username,
		Email:    userData.Email,
	}, nil
}

// ToHandle converts the User to an interop handle
func (u *User) ToHandle() uint64 {
	return interop.CreateUserHandle(u.ID, u.Username, u.Email)
}
