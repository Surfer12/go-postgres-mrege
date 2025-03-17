package com.modular.database;

import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Thread-safe prepared statement wrapper
 */
public class PreparedStatement implements AutoCloseable {
    private static final Logger logger = LoggerFactory.getLogger(PreparedStatement.class);
    private final int connectionHandle;
    private final int statementHandle;
    private final ReentrantLock statementLock = new ReentrantLock();
    private volatile boolean closed = false;
    
    /**
     * Creates a prepared statement wrapper
     */
    PreparedStatement(int connectionHandle, int statementHandle) {
        this.connectionHandle = connectionHandle;
        this.statementHandle = statementHandle;
        logger.trace("Created prepared statement with handle: {}", statementHandle);
    }
    
    /**
     * Binds an integer parameter
     * @param index Parameter index (1-based)
     * @param value Integer value to bind
     * @throws DatabaseException if binding fails
     */
    public void bindInt(int index, int value) throws DatabaseException {
        checkClosed();
        if (index < 1) {
            throw new DatabaseException("Parameter index must be >= 1");
        }
        
        statementLock.lock();
        try {
            logger.trace("Binding integer parameter at index {}: {}", index, value);
            int result = Interop.bindIntParameter(connectionHandle, statementHandle, index, value);
            if (result <= 0) {
                throw new DatabaseException("Failed to bind integer parameter");
            }
        } catch (Exception e) {
            logger.error("Error binding integer parameter: {}", e.getMessage());
            throw new DatabaseException("Error binding integer parameter", e);
        } finally {
            statementLock.unlock();
        }
    }
    
    /**
     * Binds a string parameter
     * @param index Parameter index (1-based) 
     * @param value String value to bind
     * @throws DatabaseException if binding fails
     */
    public void bindString(int index, String value) throws DatabaseException {
        checkClosed();
        if (index < 1) {
            throw new DatabaseException("Parameter index must be >= 1");
        }
        
        statementLock.lock();
        try {
            logger.trace("Binding string parameter at index {}: {}", index, value);
            int result = Interop.bindStringParameter(connectionHandle, statementHandle, index, value);
            if (result <= 0) {
                throw new DatabaseException("Failed to bind string parameter");
            }
        } catch (Exception e) {
            logger.error("Error binding string parameter: {}", e.getMessage());
            throw new DatabaseException("Error binding string parameter", e);
        } finally {
            statementLock.unlock();
        }
    }
    
    /**
     * Executes the prepared statement
     * @return QueryResult containing the results
     * @throws DatabaseException if execution fails
     */
    public QueryResult execute() throws DatabaseException {
        checkClosed();
        statementLock.lock();
        try {
            logger.debug("Executing prepared statement");
            int resultId = Interop.executePrepared(connectionHandle, statementHandle);
            if (resultId <= 0) {
                String errorMessage = Interop.getLastError(connectionHandle);
                logger.error("Prepared statement execution failed: {}", errorMessage);
                throw new DatabaseException("Prepared statement execution failed: " + errorMessage);
            }
            
            QueryResult result = new QueryResult(resultId);
            logger.debug("Prepared statement executed successfully");
            return result;
        } catch (Exception e) {
            logger.error("Error executing prepared statement: {}", e.getMessage());
            throw new DatabaseException("Error executing prepared statement", e);
        } finally {
            statementLock.unlock();
        }
    }
    
    private void checkClosed() throws DatabaseException {
        if (closed) {
            throw new DatabaseException("Prepared statement is closed");
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
        
        statementLock.lock();
        try {
            if (!closed) {
                logger.debug("Closing prepared statement");
                try {
                    Interop.closePrepared(connectionHandle, statementHandle);
                    logger.trace("Prepared statement with handle {} closed", statementHandle);
                } catch (Exception e) {
                    logger.error("Error closing prepared statement: {}", e.getMessage());
                } finally {
                    closed = true;
                }
            }
        } finally {
            statementLock.unlock();
        }
    }
    
    /**
     * Ensures resources are freed even if close() is not called
     */
    @Override
    protected void finalize() throws Throwable {
        try {
            if (!closed) {
                logger.warn("Prepared statement was not properly closed, cleaning up in finalizer");
                close();
            }
        } finally {
            super.finalize();
        }
    }
}

// Add to Interop class
public static native int prepareStatement(int connectionId, String sql);
public static native int bindIntParameter(int connectionId, int statementId, int paramIndex, int value);
public static native int bindStringParameter(int connectionId, int statementId, int paramIndex, String value);
public static native int executePrepared(int connectionId, int statementId);
public static native void closePrepared(int connectionId, int statementId);

// Add to DatabaseConnector class
/**
 * Prepares a SQL statement for repeated execution
 * @param sql SQL statement with placeholders (?)
 * @return PreparedStatement object
 * @throws DatabaseException if preparation fails
 */
public PreparedStatement prepare(String sql) throws DatabaseException {
    if (!isConnected.get()) {
        logger.error("Attempted to prepare statement while not connected");
        throw new DatabaseStateException("Not connected to database");
    }
    
    logger.debug("Preparing statement: {}", sql);
    connectionLock.lock();
    try {
        validateConnection();
        
        int statementId = Interop.prepareStatement(connectionHandle, sql);
        if (statementId <= 0) {
            String errorMessage = Interop.getLastError(connectionHandle);
            logger.error("Statement preparation failed: {}", errorMessage);
            throw new DatabaseException("Failed to prepare statement: " + errorMessage);
        }
        
        logger.debug("Statement prepared successfully");
        return new PreparedStatement(connectionHandle, statementId);
    } catch (DatabaseException e) {
        throw e;
    } catch (Exception e) {
        logger.error("Error preparing statement: {}", e.getMessage());
        throw new DatabaseException("Error preparing statement", e);
    } finally {
        connectionLock.unlock();
    }
} 