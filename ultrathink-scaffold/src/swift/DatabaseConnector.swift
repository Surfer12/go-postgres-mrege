/**
 * Swift Database Connector Implementation
 * Uses Magic library for interoperability with Mojo and Java
 */
import Foundation
import Magic
import os.log

/**
 * Memory-safe Swift database connector that follows the principles
 * from the memory_safety_guide.md
 */
public class DatabaseConnector {
    // Logger for tracking operations
    private let logger = OSLog(subsystem: "com.modular.database", category: "DatabaseConnector")
    
    private let connectionString: String
    private var connectionHandle: Int = 0
    private var isConnected: Bool = false
    private let connectionQueue = DispatchQueue(label: "com.modular.database.connection", attributes: .concurrent)
    private let connectionSemaphore = DispatchSemaphore(value: 1)
    
    // Configuration options
    private var connectionTimeout: Int = 30 // seconds
    private var queryTimeout: Int = 60 // seconds
    private var maxRetries: Int = 3
    private var autoReconnect: Bool = true
    
    /**
     * Initializes a new database connector
     * - Parameter connectionString: The connection string for the database
     */
    public init(connectionString: String) {
        // Mask password in logs
        let maskedString = connectionString.replacingOccurrences(
            of: "password=[^;]*", 
            with: "password=****", 
            options: .regularExpression
        )
        os_log("Initializing database connector with connection string: %{public}@", 
               log: logger, type: .debug, maskedString)
        
        self.connectionString = connectionString
    }
    
    /**
     * Connects to the database with thread safety
     * - Throws: DatabaseError if connection fails
     */
    public func connect() throws {
        // Check if already connected without locking
        if isConnected {
            os_log("Connection already established, reusing existing connection", 
                   log: logger, type: .debug)
            return
        }
        
        // Use a semaphore for thread safety
        connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }
        
        // Double-check after acquiring semaphore
        if isConnected {
            return
        }
        
        os_log("Establishing database connection", log: logger, type: .info)
        var retryCount = 0
        var lastError: Error?
        
        while retryCount < maxRetries {
            do {
                let handle = Interop.createConnection(connectionString: connectionString)
                if handle <= 0 {
                    lastError = DatabaseError.connectionFailed
                    retryCount += 1
                    os_log("Connection attempt %d failed", log: logger, type: .warn, retryCount)
                    
                    if retryCount < maxRetries {
                        Thread.sleep(forTimeInterval: TimeInterval(retryCount))
                    }
                    continue
                }
                
                connectionHandle = handle
                isConnected = true
                os_log("Database connection established successfully", log: logger, type: .info)
                return
            } catch {
                lastError = error
                retryCount += 1
                os_log("Connection attempt %d failed: %{public}@", 
                       log: logger, type: .warn, retryCount, error.localizedDescription)
                
                if retryCount < maxRetries {
                    Thread.sleep(forTimeInterval: TimeInterval(retryCount))
                }
            }
        }
        
        os_log("Failed to connect to database after %d attempts", 
               log: logger, type: .error, maxRetries)
        throw lastError ?? DatabaseError.connectionFailed
    }
    
    /**
     * Validates the current connection is still valid
     * - Throws: DatabaseError if connection is invalid
     */
    private func validateConnection() throws {
        if !isConnected {
            throw DatabaseError.notConnected
        }
        
        let isValid = Interop.isConnectionValid(connectionId: connectionHandle)
        if !isValid {
            os_log("Connection is invalid, attempting reconnection", log: logger, type: .warn)
            
            if autoReconnect {
                // Close existing invalid connection
                do {
                    Interop.closeConnection(connectionId: connectionHandle)
                } catch {
                    os_log("Error closing invalid connection: %{public}@", 
                           log: logger, type: .debug, error.localizedDescription)
                }
                
                // Try to reconnect
                connectionHandle = 0
                isConnected = false
                try connect()
                os_log("Successfully reconnected to database", log: logger, type: .info)
            } else {
                throw DatabaseError.connectionLost
            }
        }
    }
    
    /**
     * Executes a query and returns the results
     * - Parameter sql: The SQL query to execute
     * - Returns: A QueryResult object containing the results
     * - Throws: DatabaseError if the query fails or connection is not established
     */
    public func query(_ sql: String) throws -> QueryResult {
        if !isConnected {
            os_log("Attempted to execute query while not connected", log: logger, type: .error)
            throw DatabaseError.notConnected
        }
        
        os_log("Executing query: %{public}@", log: logger, type: .debug, sql)
        
        connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }
        
        do {
            try validateConnection()
            
            let resultHandle = Interop.executeQuery(connectionId: connectionHandle, query: sql)
            if resultHandle <= 0 {
                let errorMessage = Interop.getLastError(connectionId: connectionHandle)
                os_log("Query execution failed: %{public}@", log: logger, type: .error, errorMessage)
                throw DatabaseError.queryFailed(message: errorMessage)
            }
            
            let result = QueryResult(handle: resultHandle)
            os_log("Query executed successfully, retrieved %d rows", 
                   log: logger, type: .debug, result.rowCount)
            return result
        } catch let error as DatabaseError {
            throw error
        } catch {
            os_log("Unexpected error executing query: %{public}@", 
                   log: logger, type: .error, error.localizedDescription)
            throw DatabaseError.queryFailed(message: error.localizedDescription)
        }
    }
    
    /**
     * Executes a non-query SQL statement like INSERT, UPDATE, DELETE
     * - Parameter sql: The SQL statement to execute
     * - Returns: Number of rows affected
     * - Throws: DatabaseError if execution fails
     */
    public func execute(_ sql: String) throws -> Int {
        if !isConnected {
            os_log("Attempted to execute statement while not connected", log: logger, type: .error)
            throw DatabaseError.notConnected
        }
        
        os_log("Executing statement: %{public}@", log: logger, type: .debug, sql)
        
        connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }
        
        do {
            try validateConnection()
            
            let affectedRows = Interop.executeNonQuery(connectionId: connectionHandle, sql: sql)
            if affectedRows < 0 {
                let errorMessage = Interop.getLastError(connectionId: connectionHandle)
                os_log("Statement execution failed: %{public}@", log: logger, type: .error, errorMessage)
                throw DatabaseError.executionFailed(message: errorMessage)
            }
            
            os_log("Statement executed successfully, affected %d rows", 
                   log: logger, type: .debug, affectedRows)
            return affectedRows
        } catch let error as DatabaseError {
            throw error
        } catch {
            os_log("Unexpected error executing statement: %{public}@", 
                   log: logger, type: .error, error.localizedDescription)
            throw DatabaseError.executionFailed(message: error.localizedDescription)
        }
    }
    
    /**
     * Executes a batch of SQL statements in a transaction
     * - Parameter statements: Array of SQL statements to execute
     * - Returns: Total number of rows affected
     * - Throws: DatabaseError if any statement fails
     */
    public func executeBatch(_ statements: [String]) throws -> Int {
        if !isConnected {
            os_log("Attempted to execute batch while not connected", log: logger, type: .error)
            throw DatabaseError.notConnected
        }
        
        os_log("Executing batch with %d statements", log: logger, type: .debug, statements.count)
        
        connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }
        
        do {
            try validateConnection()
            
            // Start a transaction
            os_log("Starting transaction", log: logger, type: .debug)
            _ = try execute("BEGIN")
            
            var totalAffected = 0
            
            do {
                for sql in statements {
                    os_log("Executing batch statement: %{public}@", log: logger, type: .debug, sql)
                    let affected = try execute(sql)
                    totalAffected += affected
                }
                
                // Commit the transaction
                os_log("Committing transaction", log: logger, type: .debug)
                _ = try execute("COMMIT")
                
                os_log("Batch execution completed, affected %d rows total", 
                       log: logger, type: .info, totalAffected)
                return totalAffected
            } catch {
                // Rollback on any error
                os_log("Rolling back transaction due to error: %{public}@", 
                       log: logger, type: .warn, error.localizedDescription)
                
                do {
                    _ = try execute("ROLLBACK")
                    os_log("Transaction rolled back successfully", log: logger, type: .info)
                } catch {
                    os_log("Failed to rollback transaction: %{public}@", 
                           log: logger, type: .error, error.localizedDescription)
                }
                
                throw DatabaseError.transactionFailed(message: "Batch execution failed: \(error.localizedDescription)")
            }
        } catch {
            if let dbError = error as? DatabaseError {
                throw dbError
            }
            throw DatabaseError.transactionFailed(message: error.localizedDescription)
        }
    }
    
    /**
     * Prepares a SQL statement for repeated execution
     * - Parameter sql: SQL statement with placeholders (?)
     * - Returns: PreparedStatement object
     * - Throws: DatabaseError if preparation fails
     */
    public func prepare(_ sql: String) throws -> PreparedStatement {
        if !isConnected {
            os_log("Attempted to prepare statement while not connected", log: logger, type: .error)
            throw DatabaseError.notConnected
        }
        
        os_log("Preparing statement: %{public}@", log: logger, type: .debug, sql)
        
        connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }
        
        do {
            try validateConnection()
            
            let statementId = Interop.prepareStatement(connectionId: connectionHandle, sql: sql)
            if statementId <= 0 {
                let errorMessage = Interop.getLastError(connectionId: connectionHandle)
                os_log("Statement preparation failed: %{public}@", log: logger, type: .error, errorMessage)
                throw DatabaseError.preparationFailed(message: errorMessage)
            }
            
            os_log("Statement prepared successfully", log: logger, type: .debug)
            return PreparedStatement(connectionHandle: connectionHandle, statementHandle: statementId)
        } catch let error as DatabaseError {
            throw error
        } catch {
            os_log("Error preparing statement: %{public}@", log: logger, type: .error, error.localizedDescription)
            throw DatabaseError.preparationFailed(message: error.localizedDescription)
        }
    }
    
    /**
     * Closes the database connection and releases resources
     */
    public func close() {
        if !isConnected {
            return
        }
        
        os_log("Closing database connection", log: logger, type: .debug)
        
        connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }
        
        if isConnected {
            do {
                Interop.closeConnection(connectionId: connectionHandle)
                os_log("Database connection closed successfully", log: logger, type: .info)
            } catch {
                os_log("Error closing database connection: %{public}@", 
                       log: logger, type: .error, error.localizedDescription)
            }
            connectionHandle = 0
            isConnected = false
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
    private static let logger = OSLog(subsystem: "com.modular.database", category: "QueryResult")
    private let handle: Int
    private let resultQueue = DispatchQueue(label: "com.modular.database.result", attributes: .concurrent)
    private let resultSemaphore = DispatchSemaphore(value: 1)
    private var closed = false
    
    /**
     * Initializes with a result handle from the interop layer
     */
    init(handle: Int) {
        self.handle = handle
        os_log("Created new query result with handle: %d", log: QueryResult.logger, type: .debug, handle)
    }
    
    /**
     * Gets the number of rows in the result set
     */
    public var rowCount: Int {
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }
        
        guard !closed else {
            os_log("Attempted to access closed result set", log: QueryResult.logger, type: .error)
            return 0
        }
        
        return Interop.getRowCount(resultId: handle)
    }
    
    /**
     * Gets the number of columns in the result set
     */
    public var columnCount: Int {
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }
        
        guard !closed else {
            os_log("Attempted to access closed result set", log: QueryResult.logger, type: .error)
            return 0
        }
        
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
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }
        
        if closed {
            os_log("Attempted to access closed result set", log: QueryResult.logger, type: .error)
            throw DatabaseError.resultSetClosed
        }
        
        let rowCount = Interop.getRowCount(resultId: handle)
        let colCount = Interop.getColumnCount(resultId: handle)
        
        if row < 0 || row >= rowCount || column < 0 || column >= colCount {
            os_log("Index out of bounds: row=%d, column=%d, rowCount=%d, colCount=%d", 
                   log: QueryResult.logger, type: .error, row, column, rowCount, colCount)
            throw DatabaseError.indexOutOfBounds
        }
        
        let value = Interop.getValue(resultId: handle, row: row, column: column)
        os_log("Retrieved value at row=%d, column=%d: %{public}@", 
               log: QueryResult.logger, type: .debug, row, column, value)
        return value
    }
    
    /**
     * Converts the result set to an array of dictionaries
     * - Returns: An array of dictionaries representing each row
     */
    public func toArray() -> [[String: Any]] {
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }
        
        if closed {
            os_log("Attempted to access closed result set", log: QueryResult.logger, type: .error)
            return []
        }
        
        os_log("Converting result set to array", log: QueryResult.logger, type: .debug)
        
        let rowCount = Interop.getRowCount(resultId: handle)
        let colCount = Interop.getColumnCount(resultId: handle)
        
        var result: [[String: Any]] = []
        
        for i in 0..<rowCount {
            var row: [String: Any] = [:]
            for j in 0..<colCount {
                let columnName = Interop.getColumnName(resultId: handle, column: j)
                let value = Interop.getValue(resultId: handle, row: i, column: j)
                row[columnName] = value
            }
            result.append(row)
        }
        
        os_log("Successfully converted result set to array with %d rows", 
               log: QueryResult.logger, type: .debug, result.count)
        return result
    }
    
    /**
     * Thread-safe close operation
     */
    public func close() {
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }
        
        if !closed {
            os_log("Closing query result", log: QueryResult.logger, type: .debug)
            Interop.freeResult(resultId: handle)
            closed = true
            os_log("Query result with handle %d freed", log: QueryResult.logger, type: .debug, handle)
        }
    }
    
    /**
     * Releases the result resources when this object is deallocated
     */
    deinit {
        if !closed {
            os_log("Result set was not properly closed, cleaning up in deinit", 
                   log: QueryResult.logger, type: .warn)
            close()
        }
    }
}

/**
 * Memory-safe wrapper for prepared statements
 */
public class PreparedStatement {
    private static let logger = OSLog(subsystem: "com.modular.database", category: "PreparedStatement")
    private let connectionHandle: Int
    private let statementHandle: Int
    private let statementSemaphore = DispatchSemaphore(value: 1)
    private var closed = false
    
    /**
     * Initializes with connection and statement handles
     */
    init(connectionHandle: Int, statementHandle: Int) {
        self.connectionHandle = connectionHandle
        self.statementHandle = statementHandle
        os_log("Created prepared statement with handle: %d", 
               log: PreparedStatement.logger, type: .debug, statementHandle)
    }
    
    /**
     * Binds an integer parameter
     * - Parameters:
     *   - index: Parameter index (1-based)
     *   - value: Integer value to bind
     * - Throws: DatabaseError if binding fails
     */
    public func bindInt(index: Int, value: Int) throws {
        try checkClosed()
        
        if index < 1 {
            os_log("Invalid parameter index: %d", log: PreparedStatement.logger, type: .error, index)
            throw DatabaseError.invalidParameter
        }
        
        statementSemaphore.wait()
        defer { statementSemaphore.signal() }
        
        os_log("Binding integer parameter at index %d: %d", 
               log: PreparedStatement.logger, type: .debug, index, value)
        
        let result = Interop.bindIntParameter(
            connectionId: connectionHandle,
            statementId: statementHandle,
            paramIndex: index,
            value: value
        )
        
        if result <= 0 {
            let errorMessage = Interop.getLastError(connectionId: connectionHandle)
            os_log("Failed to bind integer parameter: %{public}@", 
                   log: PreparedStatement.logger, type: .error, errorMessage)
            throw DatabaseError.bindingFailed(message: errorMessage)
        }
    }
    
    /**
     * Binds a string parameter
     * - Parameters:
     *   - index: Parameter index (1-based)
     *   - value: String value to bind
     * - Throws: DatabaseError if binding fails
     */
    public func bindString(index: Int, value: String) throws {
        try checkClosed()
        
        if index < 1 {
            os_log("Invalid parameter index: %d", log: PreparedStatement.logger, type: .error, index)
            throw DatabaseError.invalidParameter
        }
        
        statementSemaphore.wait()
        defer { statementSemaphore.signal() }
        
        os_log("Binding string parameter at index %d: %{public}@", 
               log: PreparedStatement.logger, type: .debug, index, value)
        
        let result = Interop.bindStringParameter(
            connectionId: connectionHandle,
            statementId: statementHandle,
            paramIndex: index,
            value: value
        )
        
        if result <= 0 {
            let errorMessage = Interop.getLastError(connectionId: connectionHandle)
            os_log("Failed to bind string parameter: %{public}@", 
                   log: PreparedStatement.logger, type: .error, errorMessage)
            throw DatabaseError.bindingFailed(message: errorMessage)
        }
    }
    
    /**
     * Executes the prepared statement
     * - Returns: QueryResult containing the results
     * - Throws: DatabaseError if execution fails
     */
    public func execute() throws -> QueryResult {
        try checkClosed()
        
        statementSemaphore.wait()
        defer { statementSemaphore.signal() }
        
        os_log("Executing prepared statement", log: PreparedStatement.logger, type: .debug)
        
        let resultId = Interop.executePrepared(
            connectionId: connectionHandle,
            statementId: statementHandle
        )
        
        if resultId <= 0 {
            let errorMessage = Interop.getLastError(connectionId: connectionHandle)
            os_log("Prepared statement execution failed: %{public}@", 
                   log: PreparedStatement.logger, type: .error, errorMessage)
            throw DatabaseError.executionFailed(message: errorMessage)
        }
        
        os_log("Prepared statement executed successfully", 
               log: PreparedStatement.logger, type: .debug)
        return QueryResult(handle: resultId)
    }
    
    /**
     * Checks if the statement is closed
     * - Throws: DatabaseError if the statement is closed
     */
    private func checkClosed() throws {
        if closed {
            os_log("Attempted to use closed prepared statement", 
                   log: PreparedStatement.logger, type: .error)
            throw DatabaseError.statementClosed
        }
    }
    
    /**
     * Closes the prepared statement and releases resources
     */
    public func close() {
        statementSemaphore.wait()
        defer { statementSemaphore.signal() }
        
        if !closed {
            os_log("Closing prepared statement", log: PreparedStatement.logger, type: .debug)
            Interop.closePrepared(connectionId: connectionHandle, statementId: statementHandle)
            closed = true
            os_log("Prepared statement with handle %d closed", 
                   log: PreparedStatement.logger, type: .debug, statementHandle)
        }
    }
    
    /**
     * Releases resources when the statement is deallocated
     */
    deinit {
        if !closed {
            os_log("Prepared statement was not properly closed, cleaning up in deinit", 
                   log: PreparedStatement.logger, type: .warn)
            close()
        }
    }
}

/**
 * Database-related errors
 */
public enum DatabaseError: Error {
    case connectionFailed
    case connectionLost
    case notConnected
    case queryFailed(message: String)
    case executionFailed(message: String)
    case transactionFailed(message: String)
    case preparationFailed(message: String)
    case bindingFailed(message: String)
    case indexOutOfBounds
    case invalidParameter
    case resultSetClosed
    case statementClosed
    
    public var localizedDescription: String {
        switch self {
        case .connectionFailed:
            return "Failed to connect to database"
        case .connectionLost:
            return "Connection to database lost"
        case .notConnected:
            return "Not connected to database"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .preparationFailed(let message):
            return "Statement preparation failed: \(message)"
        case .bindingFailed(let message):
            return "Parameter binding failed: \(message)"
        case .indexOutOfBounds:
            return "Index out of bounds"
        case .invalidParameter:
            return "Invalid parameter"
        case .resultSetClosed:
            return "Result set is closed"
        case .statementClosed:
            return "Prepared statement is closed"
        }
    }
}

/**
 * Extensions to Interop class for Swift-specific functionality
 */
extension Interop {
    public static func getLastError(connectionId: Int) -> String {
        // This would be provided by the Magic library
        return "Error details from database connection"
    }
    
    public static func isConnectionValid(connectionId: Int) -> Bool {
        // This would be provided by the Magic library
        return true
    }
    
    public static func prepareStatement(connectionId: Int, sql: String) -> Int {
        // This would be provided by the Magic library
        return 1
    }
    
    public static func bindIntParameter(connectionId: Int, statementId: Int, paramIndex: Int, value: Int) -> Int {
        // This would be provided by the Magic library
        return 1
    }
    
    public static func bindStringParameter(connectionId: Int, statementId: Int, paramIndex: Int, value: String) -> Int {
        // This would be provided by the Magic library
        return 1
    }
    
    public static func executePrepared(connectionId: Int, statementId: Int) -> Int {
        // This would be provided by the Magic library
        return 1
    }
    
    public static func closePrepared(connectionId: Int, statementId: Int) {
        // This would be provided by the Magic library
    }
}

/**
 * Example usage of the database connector
 */
public func databaseExample() {
    let logger = OSLog(subsystem: "com.modular.database", category: "Example")
    os_log("Starting database example", log: logger, type: .info)
    
    let db = DatabaseConnector(connectionString: "postgresql://localhost:5432/mydb")
    
    do {
        try db.connect()
        
        // Query with proper error handling
        do {
            let users = try db.query("SELECT id, username, email FROM users")
            os_log("Found %d users", log: logger, type: .info, users.rowCount)
            
            // Process results safely
            for i in 0..<users.rowCount {
                do {
                    let id = try users.getValue(row: i, column: 0)
                    let username = try users.getValue(row: i, column: 1)
                    let email = try users.getValue(row: i, column: 2)
                    os_log("User: %{public}@ (ID: %{public}@, Email: %{public}@)", 
                           log: logger, type: .info, username, id, email)
                } catch {
                    os_log("Error accessing user data: %{public}@", 
                           log: logger, type: .error, error.localizedDescription)
                }
            }
            
            // Convert to array for easier processing
            let userData = users.toArray()
            if let firstUser = userData.first, let username = firstUser["username"] as? String {
                os_log("First username from array: %{public}@", log: logger, type: .info, username)
            }
        } catch {
            os_log("Query failed: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
        
        // Prepared statement example
        do {
            let stmt = try db.prepare("INSERT INTO users (username, email) VALUES (?, ?)")
            
            try stmt.bindString(index: 1, value: "swiftuser")
            try stmt.bindString(index: 2, value: "swift@example.com")
            
            let result = try stmt.execute()
            os_log("Inserted user successfully", log: logger, type: .info)
            
            stmt.close()
        } catch {
            os_log("Prepared statement failed: %{public}@", 
                   log: logger, type: .error, error.localizedDescription)
        }
        
        // Transaction example
        do {
            let statements = [
                "INSERT INTO users (username, email) VALUES ('batchuser1', 'batch1@example.com')",
                "UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE username = 'batchuser1'"
            ]
            
            let affected = try db.executeBatch(statements)
            os_log("Transaction completed, affected %d rows", log: logger, type: .info, affected)
        } catch {
            os_log("Transaction failed: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    } catch {
        os_log("Database connection failed: %{public}@", log: logger, type: .error, error.localizedDescription)
    }
    
    // Always close the connection
    db.close()
    os_log("Database example completed", log: logger, type: .info)
} 