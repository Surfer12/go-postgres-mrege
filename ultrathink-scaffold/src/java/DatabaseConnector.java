/**
 * Java Database Connector Implementation
 * Uses Magic library for interoperability with Mojo and Swift
 */
package com.modular.database;

import com.modular.magic.Interop;
import com.modular.magic.MojoAdapter;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.ArrayList;
import java.util.HashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Thread-safe and memory-safe database connector for Java
 * that integrates with the Magic interoperability library
 */
public class DatabaseConnector implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(DatabaseConnector.class);
    private final String connectionString;
    private final ReentrantLock connectionLock = new ReentrantLock();
    private final AtomicBoolean isConnected = new AtomicBoolean(false);
    private int connectionHandle = 0;
    
    // Configuration options
    private int connectionTimeout = 30; // seconds
    private int queryTimeout = 60; // seconds
    private int maxRetries = 3;
    private boolean autoReconnect = true;
    
    /**
     * Creates a new database connector
     * @param connectionString The connection string to the database
     */
    public DatabaseConnector(String connectionString) {
        logger.debug("Initializing database connector with connection string: {}", 
                     connectionString.replaceAll("password=\\w+", "password=****"));
        this.connectionString = connectionString;
    }
    
    /**
     * Connects to the database with thread safety
     * @throws DatabaseConnectionException if connection fails
     */
    public void connect() throws DatabaseConnectionException {
        // Only lock if we're not already connected
        if (isConnected.get()) {
            logger.debug("Connection already established, reusing existing connection");
            return;
        }
        
        connectionLock.lock();
        try {
            // Double-check after acquiring lock
            if (isConnected.get()) {
                return;
            }
            
            logger.info("Establishing database connection");
            int retryCount = 0;
            Exception lastException = null;
            
            while (retryCount < maxRetries) {
                try {
                    int handle = Interop.createConnection(connectionString);
                    if (handle <= 0) {
                        lastException = new DatabaseConnectionException("Failed to connect to database", null);
                        retryCount++;
                        logger.warn("Connection attempt {} failed", retryCount);
                        if (retryCount < maxRetries) {
                            Thread.sleep(1000 * retryCount); // Exponential backoff
                        }
                        continue;
                    }
                    
                    connectionHandle = handle;
                    isConnected.set(true);
                    logger.info("Database connection established successfully");
                    return;
                } catch (Exception e) {
                    lastException = e;
                    retryCount++;
                    logger.warn("Connection attempt {} failed: {}", retryCount, e.getMessage());
                    if (retryCount < maxRetries) {
                        try {
                            Thread.sleep(1000 * retryCount); // Exponential backoff
                        } catch (InterruptedException ie) {
                            Thread.currentThread().interrupt();
                            throw new DatabaseConnectionException("Connection interrupted", ie);
                        }
                    }
                }
            }
            
            logger.error("Failed to connect to database after {} attempts", maxRetries);
            throw new DatabaseConnectionException("Failed to connect to database after " + maxRetries + " attempts", 
                                                 lastException);
        } finally {
            connectionLock.unlock();
        }
    }
    
    /**
     * Thread-safe query execution
     * @param sql SQL query to execute
     * @return Result object with thread-safe access methods
     * @throws DatabaseQueryException if query fails or not connected
     */
    public QueryResult query(String sql) throws DatabaseException {
        if (!isConnected.get()) {
            logger.error("Attempted to execute query while not connected");
            throw new DatabaseStateException("Not connected to database");
        }
        
        logger.debug("Executing query: {}", sql);
        // Use a read lock for querying
        connectionLock.lock();
        try {
            validateConnection();
            
            int resultId = Interop.executeQuery(connectionHandle, sql);
            if (resultId <= 0) {
                String errorMessage = Interop.getLastError(connectionHandle);
                logger.error("Query execution failed: {}", errorMessage);
                throw new DatabaseQueryException("Query execution failed: " + errorMessage);
            }
            
            QueryResult result = new QueryResult(resultId);
            logger.debug("Query executed successfully, retrieved {} rows", result.getRowCount());
            return result;
        } catch (DatabaseException e) {
            // Re-throw database exceptions
            throw e;
        } catch (Exception e) {
            logger.error("Unexpected error executing query: {}", e.getMessage(), e);
            throw new DatabaseQueryException("Error executing query", e);
        } finally {
            connectionLock.unlock();
        }
    }
    
    /**
     * Thread-safe execution of non-query SQL
     * @param sql SQL statement to execute
     * @return Number of rows affected
     * @throws DatabaseUpdateException if execution fails or not connected
     */
    public int execute(String sql) throws DatabaseException {
        if (!isConnected.get()) {
            logger.error("Attempted to execute statement while not connected");
            throw new DatabaseStateException("Not connected to database");
        }
        
        logger.debug("Executing statement: {}", sql);
        // Use a write lock for modification operations
        connectionLock.lock();
        try {
            validateConnection();
            
            int affectedRows = Interop.executeNonQuery(connectionHandle, sql);
            if (affectedRows < 0) {
                String errorMessage = Interop.getLastError(connectionHandle);
                logger.error("Statement execution failed: {}", errorMessage);
                throw new DatabaseUpdateException("Statement execution failed: " + errorMessage);
            }
            
            logger.debug("Statement executed successfully, affected {} rows", affectedRows);
            return affectedRows;
        } catch (DatabaseException e) {
            // Re-throw database exceptions
            throw e;
        } catch (Exception e) {
            logger.error("Unexpected error executing statement: {}", e.getMessage(), e);
            throw new DatabaseUpdateException("Error executing statement", e);
        } finally {
            connectionLock.unlock();
        }
    }
    
    /**
     * Thread-safe batch operations using a transaction
     * @param statements List of SQL statements to execute as a batch
     * @return Number of rows affected by all statements
     * @throws DatabaseTransactionException if any statement fails
     */
    public int executeBatch(List<String> statements) throws DatabaseException {
        if (!isConnected.get()) {
            logger.error("Attempted to execute batch while not connected");
            throw new DatabaseStateException("Not connected to database");
        }
        
        logger.debug("Executing batch with {} statements", statements.size());
        connectionLock.lock();
        try {
            validateConnection();
            
            // Start a transaction
            logger.debug("Starting transaction");
            Interop.executeNonQuery(connectionHandle, "BEGIN");
            
            int totalAffected = 0;
            try {
                for (String sql : statements) {
                    logger.trace("Executing batch statement: {}", sql);
                    int affected = Interop.executeNonQuery(connectionHandle, sql);
                    if (affected < 0) {
                        String errorMessage = Interop.getLastError(connectionHandle);
                        logger.error("Batch statement failed: {}", errorMessage);
                        throw new DatabaseUpdateException("Batch statement failed: " + errorMessage);
                    }
                    totalAffected += affected;
                }
                
                // Commit the transaction
                logger.debug("Committing transaction");
                Interop.executeNonQuery(connectionHandle, "COMMIT");
                logger.info("Batch execution completed, affected {} rows total", totalAffected);
                return totalAffected;
            } catch (Exception e) {
                // Rollback on any error
                logger.warn("Rolling back transaction due to error: {}", e.getMessage());
                try {
                    Interop.executeNonQuery(connectionHandle, "ROLLBACK");
                    logger.info("Transaction rolled back successfully");
                } catch (Exception rollbackEx) {
                    logger.error("Failed to rollback transaction: {}", rollbackEx.getMessage());
                }
                
                if (e instanceof DatabaseException) {
                    throw e;
                }
                throw new DatabaseTransactionException("Batch execution failed", e);
            }
        } finally {
            connectionLock.unlock();
        }
    }
    
    /**
     * Validates the current connection is still valid
     * @throws DatabaseConnectionException if connection is invalid
     */
    private void validateConnection() throws DatabaseConnectionException {
        if (!isConnected.get()) {
            throw new DatabaseStateException("Not connected to database");
        }
        
        try {
            if (!Interop.isConnectionValid(connectionHandle)) {
                logger.warn("Connection is invalid, attempting reconnection");
                if (autoReconnect) {
                    // Close existing invalid connection
                    try {
                        Interop.closeConnection(connectionHandle);
                    } catch (Exception e) {
                        logger.debug("Error closing invalid connection: {}", e.getMessage());
                    }
                    
                    // Try to reconnect
                    connectionHandle = 0;
                    isConnected.set(false);
                    connect();
                    logger.info("Successfully reconnected to database");
                } else {
                    throw new DatabaseConnectionException("Connection to database lost");
                }
            }
        } catch (DatabaseConnectionException e) {
            throw e;
        } catch (Exception e) {
            logger.error("Error validating connection: {}", e.getMessage());
            throw new DatabaseConnectionException("Error validating database connection", e);
        }
    }
    
    /**
     * Thread-safe connection close operation
     */
    @Override
    public void close() {
        if (!isConnected.get()) {
            return;
        }
        
        logger.debug("Closing database connection");
        connectionLock.lock();
        try {
            if (isConnected.get()) {
                try {
                    Interop.closeConnection(connectionHandle);
                    logger.info("Database connection closed successfully");
                } catch (Exception e) {
                    logger.error("Error closing database connection: {}", e.getMessage(), e);
                } finally {
                    connectionHandle = 0;
                    isConnected.set(false);
                }
            }
        } finally {
            connectionLock.unlock();
        }
    }
    
    /**
     * Thread-safe result wrapper
     */
    public static class QueryResult implements AutoCloseable {
        private static final Logger logger = LoggerFactory.getLogger(QueryResult.class);
        private final int resultHandle;
        private final ReentrantLock resultLock = new ReentrantLock();
        private volatile boolean closed = false;
        
        QueryResult(int resultHandle) {
            this.resultHandle = resultHandle;
            logger.trace("Created new query result with handle: {}", resultHandle);
        }
        
        /**
         * Thread-safe row count accessor
         */
        public int getRowCount() throws DatabaseException {
            checkClosed();
            resultLock.lock();
            try {
                return Interop.getRowCount(resultHandle);
            } catch (Exception e) {
                logger.error("Error getting row count: {}", e.getMessage());
                throw new DatabaseQueryException("Failed to get row count", e);
            } finally {
                resultLock.unlock();
            }
        }
        
        /**
         * Thread-safe column count accessor
         */
        public int getColumnCount() throws DatabaseException {
            checkClosed();
            resultLock.lock();
            try {
                return Interop.getColumnCount(resultHandle);
            } catch (Exception e) {
                logger.error("Error getting column count: {}", e.getMessage());
                throw new DatabaseQueryException("Failed to get column count", e);
            } finally {
                resultLock.unlock();
            }
        }
        
        /**
         * Thread-safe value accessor
         */
        public String getValue(int row, int column) throws DatabaseException {
            checkClosed();
            resultLock.lock();
            try {
                int rowCount = Interop.getRowCount(resultHandle);
                int colCount = Interop.getColumnCount(resultHandle);
                
                if (row < 0 || row >= rowCount || column < 0 || column >= colCount) {
                    logger.error("Index out of bounds: row={}, column={}, rowCount={}, colCount={}", 
                                row, column, rowCount, colCount);
                    throw new DatabaseDataException("Index out of bounds");
                }
                
                String value = Interop.getValue(resultHandle, row, column);
                logger.trace("Retrieved value at row={}, column={}: {}", row, column, value);
                return value;
            } catch (DatabaseException e) {
                throw e;
            } catch (Exception e) {
                logger.error("Error getting value at row={}, column={}: {}", row, column, e.getMessage());
                throw new DatabaseQueryException("Failed to get value", e);
            } finally {
                resultLock.unlock();
            }
        }
        
        /**
         * Thread-safe conversion to list of maps
         * Returns a thread-safe defensive copy
         */
        public List<Map<String, String>> toList() throws DatabaseException {
            checkClosed();
            resultLock.lock();
            try {
                logger.debug("Converting result set to list of maps");
                int rowCount = Interop.getRowCount(resultHandle);
                int colCount = Interop.getColumnCount(resultHandle);
                
                List<Map<String, String>> result = new ArrayList<>(rowCount);
                for (int i = 0; i < rowCount; i++) {
                    Map<String, String> row = new HashMap<>();
                    for (int j = 0; j < colCount; j++) {
                        String columnName = Interop.getColumnName(resultHandle, j);
                        String value = Interop.getValue(resultHandle, i, j);
                        row.put(columnName, value);
                    }
                    result.add(row);
                }
                
                logger.debug("Successfully converted result set to list with {} rows", result.size());
                return result;
            } catch (DatabaseException e) {
                throw e;
            } catch (Exception e) {
                logger.error("Error converting result to list: {}", e.getMessage());
                throw new DatabaseQueryException("Failed to convert result to list", e);
            } finally {
                resultLock.unlock();
            }
        }
        
        /**
         * Thread-safe cache of result data
         * @return Thread-safe ConcurrentHashMap of results
         */
        public ConcurrentHashMap<String, List<String>> toConcurrentMap() throws DatabaseException {
            checkClosed();
            resultLock.lock();
            try {
                logger.debug("Converting result set to concurrent map");
                int rowCount = Interop.getRowCount(resultHandle);
                int colCount = Interop.getColumnCount(resultHandle);
                
                ConcurrentHashMap<String, List<String>> result = new ConcurrentHashMap<>();
                
                // Create column lists
                for (int j = 0; j < colCount; j++) {
                    String columnName = Interop.getColumnName(resultHandle, j);
                    List<String> columnValues = new ArrayList<>(rowCount);
                    for (int i = 0; i < rowCount; i++) {
                        columnValues.add(Interop.getValue(resultHandle, i, j));
                    }
                    result.put(columnName, columnValues);
                }
                
                logger.debug("Successfully converted result set to concurrent map with {} columns", result.size());
                return result;
            } catch (DatabaseException e) {
                throw e;
            } catch (Exception e) {
                logger.error("Error converting result to concurrent map: {}", e.getMessage());
                throw new DatabaseQueryException("Failed to convert result to concurrent map", e);
            } finally {
                resultLock.unlock();
            }
        }
        
        private void checkClosed() throws DatabaseException {
            if (closed) {
                logger.error("Attempted to access closed result set");
                throw new DatabaseStateException("Result set is closed");
            }
        }
        
        /**
         * Thread-safe close operation
         */
        @Override
        public void close() {
            if (closed) {
                return;
            }
            
            logger.debug("Closing query result");
            resultLock.lock();
            try {
                if (!closed) {
                    try {
                        Interop.freeResult(resultHandle);
                        logger.trace("Query result with handle {} freed", resultHandle);
                    } catch (Exception e) {
                        logger.error("Error freeing result resources: {}", e.getMessage(), e);
                    } finally {
                        closed = true;
                    }
                }
            } finally {
                resultLock.unlock();
            }
        }
        
        /**
         * Ensures resources are freed even if close() is not called
         */
        @Override
        protected void finalize() throws Throwable {
            try {
                if (!closed) {
                    logger.warn("Result set was not properly closed, cleaning up in finalizer");
                    close();
                }
            } finally {
                super.finalize();
            }
        }
    }
    
    /**
     * Base database exception class
     */
    public static class DatabaseException extends Exception {
        public DatabaseException(String message) {
            super(message);
        }
        
        public DatabaseException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Exception for connection-related errors
     */
    public static class DatabaseConnectionException extends DatabaseException {
        public DatabaseConnectionException(String message) {
            super(message);
        }
        
        public DatabaseConnectionException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Exception for query-related errors
     */
    public static class DatabaseQueryException extends DatabaseException {
        public DatabaseQueryException(String message) {
            super(message);
        }
        
        public DatabaseQueryException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Exception for data update errors
     */
    public static class DatabaseUpdateException extends DatabaseException {
        public DatabaseUpdateException(String message) {
            super(message);
        }
        
        public DatabaseUpdateException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Exception for transaction errors
     */
    public static class DatabaseTransactionException extends DatabaseException {
        public DatabaseTransactionException(String message) {
            super(message);
        }
        
        public DatabaseTransactionException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Exception for data access errors
     */
    public static class DatabaseDataException extends DatabaseException {
        public DatabaseDataException(String message) {
            super(message);
        }
        
        public DatabaseDataException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Exception for state-related errors
     */
    public static class DatabaseStateException extends DatabaseException {
        public DatabaseStateException(String message) {
            super(message);
        }
        
        public DatabaseStateException(String message, Throwable cause) {
            super(message, cause);
        }
    }
    
    /**
     * Example showing how to use the connector with proper thread safety,
     * error handling, and logging
     */
    public static void threadSafeExample() {
        Logger exampleLogger = LoggerFactory.getLogger("DatabaseExample");
        exampleLogger.info("Starting database example");
        
        try (DatabaseConnector db = new DatabaseConnector("postgresql://localhost:5432/mydb")) {
            try {
                db.connect();
            } catch (DatabaseConnectionException e) {
                exampleLogger.error("Failed to connect to database: {}", e.getMessage());
                return;
            }
            
            // Thread-safe querying with proper error handling
            try (QueryResult users = db.query("SELECT id, username, email FROM users")) {
                exampleLogger.info("Found {} users", users.getRowCount());
                
                // Process results safely
                for (int i = 0; i < users.getRowCount(); i++) {
                    try {
                        String id = users.getValue(i, 0);
                        String username = users.getValue(i, 1);
                        String email = users.getValue(i, 2);
                        exampleLogger.info("User: {} (ID: {}, Email: {})", username, id, email);
                    } catch (DatabaseDataException e) {
                        exampleLogger.error("Error accessing user data: {}", e.getMessage());
                    }
                }
                
                try {
                    // Thread-safe concurrent map for multi-threaded processing
                    ConcurrentHashMap<String, List<String>> userData = users.toConcurrentMap();
                    
                    // Now multiple threads can safely access the data
                    List<String> usernames = userData.get("username");
                    if (usernames != null) {
                        exampleLogger.info("First username: {}", usernames.get(0));
                    }
                } catch (DatabaseException e) {
                    exampleLogger.error("Error creating concurrent map: {}", e.getMessage());
                }
            } catch (DatabaseQueryException e) {
                exampleLogger.error("Query failed: {}", e.getMessage());
            } catch (DatabaseException e) {
                exampleLogger.error("Database error: {}", e.getMessage());
            }
            
            // Transaction example with error handling
            try {
                List<String> statements = new ArrayList<>();
                statements.add("INSERT INTO users (username, email) VALUES ('newuser', 'new@example.com')");
                statements.add("UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE username = 'newuser'");
                
                int affected = db.executeBatch(statements);
                exampleLogger.info("Transaction completed, affected {} rows", affected);
            } catch (DatabaseTransactionException e) {
                exampleLogger.error("Transaction failed: {}", e.getMessage());
            } catch (DatabaseException e) {
                exampleLogger.error("Database error: {}", e.getMessage());
            }
        } catch (Exception e) {
            exampleLogger.error("Unexpected error: {}", e.getMessage(), e);
        }
        
        exampleLogger.info("Database example completed");
    }
}

/**
 * Interop class for Java - Magic communication
 * This would be provided by the Magic library
 */
class Interop {
    public static native int createConnection(String connectionString);
    public static native void closeConnection(int connectionId);
    public static native int executeQuery(int connectionId, String query);
    public static native int executeNonQuery(int connectionId, String sql);
    public static native void freeResult(int resultId);
    public static native int getRowCount(int resultId);
    public static native int getColumnCount(int resultId);
    public static native String getColumnName(int resultId, int column);
    public static native String getValue(int resultId, int row, int column);
    public static native String getLastError(int connectionId);
    public static native boolean isConnectionValid(int connectionId);
} 