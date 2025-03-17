/**
 * Java Database Connector Implementation
 * Uses Magic library for interoperability with Mojo and Swift
 */
package com.example.db;

import com.modular.magic.Interop;
import com.modular.magic.MojoAdapter;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class DatabaseConnector implements AutoCloseable {
    private final String connectionString;
    private boolean isConnected;
    private long connHandle; // Safe handle instead of unsafe pointer
    
    /**
     * Creates a database connector with automatic resource management
     * 
     * @param connectionString The database connection string
     */
    public DatabaseConnector(String connectionString) {
        this.connectionString = connectionString;
        this.isConnected = false;
        this.connHandle = 0;
    }
    
    /**
     * Establishes connection to the database with safety checks
     * 
     * @return true if connection was successful
     * @throws SQLException if connection fails
     */
    public boolean connect() throws SQLException {
        if (isConnected) {
            return true;
        }
        
        // Use Magic library for safe interop with Mojo
        try {
            this.connHandle = Interop.createConnection(connectionString);
            if (this.connHandle == 0) {
                throw new SQLException("Failed to connect to database");
            }
            
            this.isConnected = true;
            return true;
        } catch (Exception e) {
            throw new SQLException("Error connecting to database: " + e.getMessage(), e);
        }
    }
    
    /**
     * Executes a query with automatic memory management for results
     * 
     * @param sql The SQL query to execute
     * @return QueryResult containing the results
     * @throws SQLException if query execution fails
     */
    public QueryResult query(String sql) throws SQLException {
        if (!isConnected) {
            throw new SQLException("Not connected to database");
        }
        
        try {
            // Use safe handle-based API
            long resultHandle = Interop.executeQuery(this.connHandle, sql);
            
            // Convert to Java-friendly QueryResult (memory-safe)
            return new QueryResult(resultHandle);
        } catch (Exception e) {
            throw new SQLException("Error executing query: " + e.getMessage(), e);
        }
    }
    
    /**
     * Executes a non-query SQL statement
     * 
     * @param sql The SQL statement to execute
     * @return Number of rows affected
     * @throws SQLException if execution fails
     */
    public int execute(String sql) throws SQLException {
        if (!isConnected) {
            throw new SQLException("Not connected to database");
        }
        
        try {
            return Interop.executeNonQuery(this.connHandle, sql);
        } catch (Exception e) {
            throw new SQLException("Error executing statement: " + e.getMessage(), e);
        }
    }
    
    /**
     * AutoCloseable implementation for automatic resource cleanup
     */
    @Override
    public void close() {
        if (isConnected) {
            Interop.closeConnection(this.connHandle);
            isConnected = false;
        }
    }
    
    /**
     * Finalizer as backup for resource cleanup
     */
    @Override
    protected void finalize() throws Throwable {
        try {
            close();
        } finally {
            super.finalize();
        }
    }
}

/**
 * Memory-safe wrapper for query results
 */
class QueryResult implements AutoCloseable {
    private final long resultHandle;
    
    QueryResult(long resultHandle) {
        this.resultHandle = resultHandle;
    }
    
    public int getRowCount() {
        return Interop.getRowCount(resultHandle);
    }
    
    public int getColumnCount() {
        return Interop.getColumnCount(resultHandle);
    }
    
    public String getValue(int row, int column) {
        return Interop.getValue(resultHandle, row, column);
    }
    
    public List<Map<String, Object>> toList() {
        return Interop.resultToList(resultHandle);
    }
    
    @Override
    public void close() {
        if (resultHandle != 0) {
            Interop.freeResult(resultHandle);
        }
    }
} 