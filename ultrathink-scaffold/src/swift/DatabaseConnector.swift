/**
 * Swift Database Connector Implementation
 * Uses Magic library for interoperability with Mojo and Java
 */
import Foundation
import Magic

/// Database connection with automatic memory management
public class DatabaseConnector {
    private let connectionString: String
    private var isConnected: Bool
    private var connHandle: UInt64 // Safe handle instead of unsafe pointer
    
    /**
     * Creates a database connector with automatic resource management
     *
     * - Parameter connectionString: The database connection string
     */
    public init(connectionString: String) {
        self.connectionString = connectionString
        self.isConnected = false
        self.connHandle = 0
    }
    
    /**
     * Establishes connection to the database with safety checks
     *
     * - Returns: `true` if connection was successful
     * - Throws: `DatabaseError` if connection fails
     */
    public func connect() throws -> Bool {
        if isConnected {
            return true
        }
        
        // Use Magic library for safe interop with Mojo
        do {
            self.connHandle = try Interop.createConnection(connectionString)
            if self.connHandle == 0 {
                throw DatabaseError.connectionFailed(message: "Failed to connect to database")
            }
            
            self.isConnected = true
            return true
        } catch {
            throw DatabaseError.connectionFailed(message: "Error connecting to database: \(error.localizedDescription)")
        }
    }
    
    /**
     * Executes a query with automatic memory management for results
     *
     * - Parameter sql: The SQL query to execute
     * - Returns: `QueryResult` containing the results
     * - Throws: `DatabaseError` if query execution fails
     */
    public func query(_ sql: String) throws -> QueryResult {
        guard isConnected else {
            throw DatabaseError.notConnected
        }
        
        do {
            // Use safe handle-based API
            let resultHandle = try Interop.executeQuery(connHandle, sql: sql)
            
            // Convert to Swift-friendly QueryResult (memory-safe)
            return QueryResult(resultHandle: resultHandle)
        } catch {
            throw DatabaseError.queryFailed(message: "Error executing query: \(error.localizedDescription)")
        }
    }
    
    /**
     * Executes a non-query SQL statement
     *
     * - Parameter sql: The SQL statement to execute
     * - Returns: Number of rows affected
     * - Throws: `DatabaseError` if execution fails
     */
    public func execute(_ sql: String) throws -> Int {
        guard isConnected else {
            throw DatabaseError.notConnected
        }
        
        do {
            return try Interop.executeNonQuery(connHandle, sql: sql)
        } catch {
            throw DatabaseError.executionFailed(message: "Error executing statement: \(error.localizedDescription)")
        }
    }
    
    /**
     * Closes the database connection and releases resources
     */
    public func close() {
        if isConnected {
            Interop.closeConnection(connHandle)
            isConnected = false
        }
    }
    
    deinit {
        close()
    }
}

/**
 * Memory-safe wrapper for query results
 */
public class QueryResult {
    private let resultHandle: UInt64
    
    init(resultHandle: UInt64) {
        self.resultHandle = resultHandle
    }
    
    public var rowCount: Int {
        return Interop.getRowCount(resultHandle)
    }
    
    public var columnCount: Int {
        return Interop.getColumnCount(resultHandle)
    }
    
    public func getValue(row: Int, column: Int) -> String {
        return Interop.getValue(resultHandle, row: row, column: column)
    }
    
    public func toArray() -> [[String: Any]] {
        return Interop.resultToArray(resultHandle)
    }
    
    deinit {
        if resultHandle != 0 {
            Interop.freeResult(resultHandle)
        }
    }
}

/// Database error types
public enum DatabaseError: Error {
    case connectionFailed(message: String)
    case notConnected
    case queryFailed(message: String)
    case executionFailed(message: String)
} 