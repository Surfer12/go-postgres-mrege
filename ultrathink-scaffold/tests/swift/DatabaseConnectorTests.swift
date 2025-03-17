import XCTest
@testable import ModularDatabase

class DatabaseConnectorTests: XCTestCase {
    var db: DatabaseConnector!
    let connectionString = "postgresql://localhost:5432/mydb"
    
    override func setUp() {
        super.setUp()
        db = DatabaseConnector(connectionString: connectionString)
        try! db.connect()
    }
    
    override func tearDown() {
        db.close()
        super.tearDown()
    }
    
    func testConnection() {
        // Connection already established in setUp
        // Simply verify it worked without exception
        XCTAssertTrue(true, "Connection should be established")
    }
    
    func testQueryResult() throws {
        let users = try db.query("SELECT id, username, email FROM users")
        let rowCount = users.rowCount
        print("Found \(rowCount) users")
        XCTAssertGreaterThan(rowCount, 0, "Should have at least 1 user")
        
        // Test value access
        let username = try users.getValue(row: 0, column: 1)
        XCTAssertFalse(username.isEmpty, "Username should not be empty")
        print("First username: \(username)")
    }
    
    func testExecute() throws {
        // Insert a test user
        let affected = try db.execute("INSERT INTO users (username, email) VALUES ('swifttest', 'swift@example.com')")
        XCTAssertEqual(affected, 1, "Should affect 1 row")
        
        // Verify the insert worked
        let result = try db.query("SELECT id FROM users WHERE username = 'swifttest'")
        XCTAssertEqual(result.rowCount, 1, "Should find 1 matching user")
        
        // Clean up
        try db.execute("DELETE FROM users WHERE username = 'swifttest'")
    }
    
    func testErrorHandling() {
        // Test invalid SQL
        XCTAssertThrowsError(try db.query("SELECT * FROM nonexistent_table")) { error in
            print("Correctly caught error: \(error)")
        }
        
        // Test out of bounds access
        do {
            let users = try db.query("SELECT id FROM users")
            XCTAssertThrowsError(try users.getValue(row: 999, column: 0)) { error in
                print("Correctly caught bounds error: \(error)")
            }
        } catch {
            XCTFail("Query should succeed but bounds check should fail")
        }
    }
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent query test")
        let threadCount = 10
        let group = DispatchGroup()
        
        for i in 0..<threadCount {
            DispatchQueue.global().async(group: group) {
                do {
                    let users = try self.db.query("SELECT id, username, email FROM users")
                    print("Thread \(i) found \(users.rowCount) users")
                    if users.rowCount > 0 {
                        let value = try users.getValue(row: 0, column: 1)
                        print("Thread \(i) read value: \(value)")
                    }
                } catch {
                    XCTFail("Thread \(i) failed: \(error)")
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testArrayConversion() throws {
        let users = try db.query("SELECT id, username, email FROM users")
        let usersArray = users.toArray()
        
        XCTAssertEqual(usersArray.count, users.rowCount, "Array should have same number of rows")
        
        if usersArray.count > 0 {
            XCTAssertNotNil(usersArray[0]["username"], "First row should have username key")
        }
    }
} 