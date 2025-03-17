/**
 * Swift Database Connector Implementation
 * Uses Magic library for interoperability with Mojo and Java
 */
import Foundation
import Magic

/**
 * Memory-safe Swift database connector that follows the principles
 * from the memory_safety_guide.md
 */
public class DatabaseConnector {
    private let connectionString: String
    private var connectionHandle: Int = 0
    private var isConnected: Bool = false
    
    /**
     * Initializes a new database connector
     * - Parameter connectionString: The connection string for the database
     */
    public init(connectionString: String) {
        self.connectionString = connectionString
    }
    
    /**
     * Connects to the database
     * - Throws: DatabaseError if connection fails
     */
    public func connect() throws {
        if isConnected {
            return
        }
        
        // Use Magic library for interoperability with Mojo
        let handle = Interop.createConnection(connectionString: connectionString)
        if handle <= 0 {
            throw DatabaseError.connectionFailed
        }
        
        self.connectionHandle = handle
        self.isConnected = true
    }
    
    /**
     * Executes a query and returns the results
     * - Parameter sql: The SQL query to execute
     * - Returns: A QueryResult object containing the results
     * - Throws: DatabaseError if the query fails or connection is not established
     */
    public func query(_ sql: String) throws -> QueryResult {
        if !isConnected {
            throw DatabaseError.notConnected
        }
        
        let resultHandle = Interop.executeQuery(connectionId: connectionHandle, query: sql)
        if resultHandle <= 0 {
            throw DatabaseError.queryFailed
        }
        
        return QueryResult(handle: resultHandle)
    }
    
    /**
     * Executes a non-query SQL statement like INSERT, UPDATE, DELETE
     * - Parameter sql: The SQL statement to execute
     * - Returns: Number of rows affected
     * - Throws: DatabaseError if execution fails
     */
    public func execute(_ sql: String) throws -> Int {
        if !isConnected {
            throw DatabaseError.notConnected
        }
        
        let affectedRows = Interop.executeNonQuery(connectionId: connectionHandle, sql: sql)
        if affectedRows < 0 {
            throw DatabaseError.executionFailed
        }
        
        return affectedRows
    }
    
    /**
     * Closes the database connection and releases resources
     */
    public func close() {
        if isConnected {
            Interop.closeConnection(connectionId: connectionHandle)
            isConnected = false
            connectionHandle = 0
        }
    }
    
    /**
     * Automatically close connection when the object is deallocated
     */
    deinit {
        close()
    }
}

/**
 * Memory-safe wrapper for query results
 */
public class QueryResult {
    private let handle: Int
    
    /**
     * Initializes with a result handle from the interop layer
     */
    init(handle: Int) {
        self.handle = handle
    }
    
    /**
     * Gets the number of rows in the result set
     */
    public var rowCount: Int {
        return Interop.getRowCount(resultId: handle)
    }
    
    /**
     * Gets the number of columns in the result set
     */
    public var columnCount: Int {
        return Interop.getColumnCount(resultId: handle)
    }
    
    /**
     * Gets a value from the result set
     * - Parameters:
     *   - row: The zero-based row index
     *   - column: The zero-based column index
     * - Returns: The value as a string
     * - Throws: DatabaseError if the indices are out of bounds
     */
    public func getValue(row: Int, column: Int) throws -> String {
        if row < 0 || row >= rowCount || column < 0 || column >= columnCount {
            throw DatabaseError.indexOutOfBounds
        }
        
        return Interop.getValue(resultId: handle, row: row, column: column)
    }
    
    /**
     * Converts the result set to an array of dictionaries
     * - Returns: An array of dictionaries representing each row
     */
    public func toArray() -> [[String: Any]] {
        return Interop.resultToArray(resultId: handle)
    }
    
    /**
     * Releases the result resources when this object is deallocated
     */
    deinit {
        Interop.freeResult(resultId: handle)
    }
}

/**
 * Database-related errors
 */
public enum DatabaseError: Error {
    case connectionFailed
    case notConnected
    case queryFailed
    case executionFailed
    case indexOutOfBounds
}

/**
 * Example usage
 */
func databaseExample() {
    do {
        // Create connector with automatic resource management
        let db = DatabaseConnector(connectionString: "postgresql://localhost:5432/mydb")
        
        // Connect - resources managed through Swift's ARC
        try db.connect()
        
        // Query with automatic resource management
        let users = try db.query("SELECT id, username, email FROM users")
        print("Found \(users.rowCount) users")
        
        // Process results safely
        for row in 0..<users.rowCount {
            let id = try users.getValue(row: row, column: 0)
            let username = try users.getValue(row: row, column: 1)
            let email = try users.getValue(row: row, column: 2)
            print("User: \(username) (ID: \(id), Email: \(email))")
        }
        
        // No need for explicit cleanup - resources are automatically managed
    } catch {
        print("Error: \(error)")
    }
    
    // Even if exceptions occur, resources are automatically cleaned up
} 