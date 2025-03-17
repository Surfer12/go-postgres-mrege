from db_connector import DBConnector, QueryResult
import testing

fn test_connection() raises:
    # Test connection lifecycle
    var db = DBConnector("postgresql://localhost:5432/mydb")
    
    try:
        db.connect()
        print("✓ Connection successful")
    except:
        print("✗ Connection failed")
        raise
    
    # Connection will auto-close via RAII

fn test_query() raises:
    var db = DBConnector("postgresql://localhost:5432/mydb")
    
    try:
        db.connect()
        let users = db.query("SELECT id, username, email FROM users")
        print("✓ Query executed successfully")
        
        let count = users.get_row_count()
        print("Found " + str(count) + " users")
        
        # Test result access
        if count > 0:
            let username = users.get_value(0, 1)
            print("First username: " + username)
    except:
        print("✗ Query test failed")
        raise

fn test_error_handling() raises:
    var db = DBConnector("postgresql://localhost:5432/mydb")
    
    try:
        db.connect()
        
        try:
            # Test invalid SQL
            let _ = db.query("SELECT * FROM nonexistent_table")
            print("✗ Should have raised error for invalid table")
        except:
            print("✓ Correctly caught invalid table error")
        
        try:
            # Test out of bounds access
            let users = db.query("SELECT id FROM users")
            let _ = users.get_value(999, 0)
            print("✗ Should have raised error for out of bounds access")
        except:
            print("✓ Correctly caught out of bounds error")
    except:
        print("✗ Connection failed")
        raise

fn main() raises:
    print("Running Mojo DB Connector tests...")
    test_connection()
    test_query()
    test_error_handling()
    print("All tests completed.") 