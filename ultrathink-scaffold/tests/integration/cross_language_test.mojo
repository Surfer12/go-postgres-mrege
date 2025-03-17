"""
# Cross-language integration tests
# Tests that Mojo, Java, and Swift connectors can interact correctly

from shared.interfaces import DBInterface
from magic import interop
from max import foreign

fn test_mojo_connection():
    """Test basic Mojo connection."""
    var db = mojo.database_connector.DBConnector("postgresql://localhost:5432/testdb")
    assert db.connect()
    assert db.is_connected
    
    # Test a simple query
    let result = db.query("SELECT 1 as test")
    assert result.get_row_count() == 1
    assert result.get_column_count() == 1
    assert result.get_value(0, 0) == "1"
    
    # Connection should be closed automatically by ownership system

fn test_java_connection():
    """Test calling Java connector from Mojo."""
    # Use Max library to call Java
    var java_connector = foreign.java_invoke(
        "com.example.db.DatabaseConnector", 
        "postgresql://localhost:5432/testdb"
    )
    
    # Call connect method
    let connected = foreign.java_method_call(java_connector, "connect")
    assert connected
    
    # Execute a query
    let result = foreign.java_method_call(java_connector, "query", "SELECT 1 as test")
    
    # Get values from result
    let row_count = foreign.java_method_call(result, "getRowCount")
    assert row_count == 1
    
    let column_count = foreign.java_method_call(result, "getColumnCount")
    assert column_count == 1
    
    let value = foreign.java_method_call(result, "getValue", 0, 0)
    assert value == "1"
    
    # Close connection and release resources
    foreign.java_method_call(java_connector, "close")

fn test_swift_connection():
    """Test calling Swift connector from Mojo."""
    # Use Max library to call Swift
    var swift_connector = foreign.swift_invoke(
        "DatabaseConnector", 
        "postgresql://localhost:5432/testdb"
    )
    
    # Call connect method
    let connected = foreign.swift_method_call(swift_connector, "connect")
    assert connected
    
    # Execute a query
    let result = foreign.swift_method_call(swift_connector, "query", "SELECT 1 as test")
    
    # Get values from result
    let row_count = foreign.swift_property_get(result, "rowCount")
    assert row_count == 1
    
    let column_count = foreign.swift_property_get(result, "columnCount")
    assert column_count == 1
    
    let value = foreign.swift_method_call(result, "getValue", {"row": 0, "column": 0})
    assert value == "1"
    
    # Close connection and release resources
    foreign.swift_method_call(swift_connector, "close")

fn test_cross_language_results():
    """Test that results are consistent across languages."""
    # Create connectors in each language
    var mojo_db = mojo.database_connector.DBConnector("postgresql://localhost:5432/testdb")
    var java_db = foreign.java_invoke("com.example.db.DatabaseConnector", "postgresql://localhost:5432/testdb")
    var swift_db = foreign.swift_invoke("DatabaseConnector", "postgresql://localhost:5432/testdb")
    
    # Connect all
    mojo_db.connect()
    foreign.java_method_call(java_db, "connect")
    foreign.swift_method_call(swift_db, "connect")
    
    # Run the same query in all languages
    let sql = "SELECT id, name FROM test_table ORDER BY id LIMIT 5"
    let mojo_result = mojo_db.query(sql)
    let java_result = foreign.java_method_call(java_db, "query", sql)
    let swift_result = foreign.swift_method_call(swift_db, "query", sql)
    
    # Verify row counts match
    let mojo_rows = mojo_result.get_row_count()
    let java_rows = foreign.java_method_call(java_result, "getRowCount")
    let swift_rows = foreign.swift_property_get(swift_result, "rowCount")
    assert mojo_rows == java_rows
    assert mojo_rows == swift_rows
    
    # Compare values in each result set
    for i in range(mojo_rows):
        let mojo_id = mojo_result.get_value(i, 0)
        let mojo_name = mojo_result.get_value(i, 1)
        
        let java_id = foreign.java_method_call(java_result, "getValue", i, 0)
        let java_name = foreign.java_method_call(java_result, "getValue", i, 1)
        
        let swift_id = foreign.swift_method_call(swift_result, "getValue", {"row": i, "column": 0})
        let swift_name = foreign.swift_method_call(swift_result, "getValue", {"row": i, "column": 1})
        
        # Values should be identical across languages
        assert mojo_id == java_id == swift_id
        assert mojo_name == java_name == swift_name
    
    # Clean up
    # Mojo handles cleanup automatically with ownership system
    foreign.java_method_call(java_db, "close")
    foreign.swift_method_call(swift_db, "close")

fn main():
    """Run all integration tests."""
    print("Running cross-language integration tests...")
    
    test_mojo_connection()
    print("✓ Mojo connection test passed")
    
    test_java_connection()
    print("✓ Java connection test passed")
    
    test_swift_connection()
    print("✓ Swift connection test passed")
    
    test_cross_language_results()
    print("✓ Cross-language results test passed")
    
    print("All tests passed!")
""" 