package com.modular.database;

import org.junit.Before;
import org.junit.Test;
import org.junit.After;
import static org.junit.Assert.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.logging.Logger;

public class DatabaseConnectorTest {
    private static final Logger logger = Logger.getLogger(DatabaseConnectorTest.class.getName());
    private DatabaseConnector db;
    private final String connectionString = "postgresql://localhost:5432/mydb";
    
    @Before
    public void setUp() throws DatabaseException {
        db = new DatabaseConnector(connectionString);
        db.connect();
    }
    
    @After
    public void tearDown() {
        if (db != null) {
            db.close();
        }
    }
    
    @Test
    public void testConnection() throws DatabaseException {
        // Connection already established in setUp
        // Simply verify it worked without exception
        assertTrue("Connection should be established", true);
    }
    
    @Test
    public void testQueryResult() throws DatabaseException {
        try (QueryResult users = db.query("SELECT id, username, email FROM users")) {
            int rowCount = users.getRowCount();
            logger.info("Found " + rowCount + " users");
            assertTrue("Should have at least 1 user", rowCount > 0);
            
            // Test value access
            String username = users.getValue(0, 1);
            assertNotNull("Username should not be null", username);
            logger.info("First username: " + username);
        }
    }
    
    @Test
    public void testExecute() throws DatabaseException {
        // Insert a test user
        int affected = db.execute(
            "INSERT INTO users (username, email) VALUES ('testuser', 'test@example.com')"
        );
        assertEquals("Should affect 1 row", 1, affected);
        
        // Verify the insert worked
        try (QueryResult result = db.query(
            "SELECT id FROM users WHERE username = 'testuser'"
        )) {
            assertEquals("Should find 1 matching user", 1, result.getRowCount());
        }
        
        // Clean up
        db.execute("DELETE FROM users WHERE username = 'testuser'");
    }
    
    @Test
    public void testBatchExecution() throws DatabaseException {
        List<String> statements = new ArrayList<>();
        statements.add("INSERT INTO users (username, email) VALUES ('batch1', 'batch1@example.com')");
        statements.add("INSERT INTO users (username, email) VALUES ('batch2', 'batch2@example.com')");
        
        int affected = db.executeBatch(statements);
        assertEquals("Should affect 2 rows total", 2, affected);
        
        // Verify both inserts worked
        try (QueryResult result = db.query(
            "SELECT id FROM users WHERE username LIKE 'batch%'"
        )) {
            assertEquals("Should find 2 batch users", 2, result.getRowCount());
        }
        
        // Clean up
        db.execute("DELETE FROM users WHERE username LIKE 'batch%'");
    }
    
    @Test
    public void testConcurrentAccess() throws Exception {
        int threadCount = 10;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch latch = new CountDownLatch(threadCount);
        AtomicInteger successCount = new AtomicInteger(0);
        
        for (int i = 0; i < threadCount; i++) {
            final int threadId = i;
            executor.submit(() -> {
                try {
                    // Each thread queries and accesses results
                    try (QueryResult users = db.query("SELECT id, username, email FROM users")) {
                        logger.info("Thread " + threadId + " found " + users.getRowCount() + " users");
                        if (users.getRowCount() > 0) {
                            String value = users.getValue(0, 1);
                            logger.info("Thread " + threadId + " read value: " + value);
                            successCount.incrementAndGet();
                        }
                    }
                } catch (Exception e) {
                    logger.severe("Thread " + threadId + " failed: " + e.getMessage());
                } finally {
                    latch.countDown();
                }
            });
        }
        
        latch.await(); // Wait for all threads to complete
        executor.shutdown();
        
        assertEquals("All threads should succeed", threadCount, successCount.get());
    }
    
    @Test(expected = DatabaseQueryException.class)
    public void testInvalidQuery() throws DatabaseException {
        db.query("SELECT * FROM nonexistent_table");
        fail("Should have thrown exception for invalid table");
    }
    
    @Test(expected = DatabaseStateException.class)
    public void testClosedResultAccess() throws DatabaseException {
        QueryResult result = db.query("SELECT id FROM users");
        result.close();
        result.getRowCount(); // Should throw exception
    }
    
    @Test
    public void testConcurrentMap() throws DatabaseException {
        try (QueryResult users = db.query("SELECT id, username, email FROM users")) {
            ConcurrentHashMap<String, List<String>> userData = users.toConcurrentMap();
            
            assertNotNull("Should have username column", userData.get("username"));
            assertNotNull("Should have email column", userData.get("email"));
            
            List<String> usernames = userData.get("username");
            assertEquals("Map should have same row count", users.getRowCount(), usernames.size());
        }
    }
} 