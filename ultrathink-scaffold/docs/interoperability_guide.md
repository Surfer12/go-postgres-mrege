# Memory-Safe Interoperability Guide

This document provides comprehensive guidance on using the database connectors with Mojo, Java, and Swift while maintaining memory safety and performance.

## Overview

Our database connector system is designed with these core principles:

1. **Memory Safety**: Eliminates memory-related bugs while maintaining performance
2. **Interoperability**: Seamless interaction between Mojo, Java, and Swift
3. **Consistent API**: Common patterns across all languages
4. **Automatic Resource Management**: No manual memory cleanup required

## Memory Safety Approach

Instead of using raw pointers and manual memory management, our connectors use:

- **Handle-based APIs**: Connections and results are referenced via opaque handles
- **Automatic Cleanup**: Resources are released when objects are destroyed
- **Reference Counting**: For shared resources
- **Exception Safety**: Proper cleanup even when errors occur

## Cross-Language Communication

### The Magic Library

The `Magic` library provides the foundation for cross-language interoperability:

```mojo
# Mojo
from magic import interop

# Create a connection
let handle = interop.create_connection("connection_string")

# Execute a query 
let result_handle = interop.execute_query(handle, "SELECT * FROM users")

# Access results safely
let rows = interop.get_row_count(result_handle)

# Automatic cleanup
# No explicit free calls needed
```

```java
// Java
import com.modular.magic.Interop;

// Create a connection
long handle = Interop.createConnection("connection_string");

// Execute a query
long resultHandle = Interop.executeQuery(handle, "SELECT * FROM users");

// Access results safely
int rows = Interop.getRowCount(resultHandle);

// Use try-with-resources for automatic cleanup
try (QueryResult result = new QueryResult(resultHandle)) {
    // Use result
}
```

```swift
// Swift
import Magic

// Create a connection
let handle = try Interop.createConnection("connection_string")

// Execute a query
let resultHandle = try Interop.executeQuery(handle, sql: "SELECT * FROM users")

// Access results safely
let rows = Interop.getRowCount(resultHandle)

// ARC handles cleanup automatically
```

## The Max Library for Foreign Function Interface

For direct cross-language calls, we use the `Max` library:

```mojo
# Call Java from Mojo
from max import foreign

# Create Java object
let java_obj = foreign.java_invoke("com.example.db.DatabaseConnector", "connection_string")

# Call method
let result = foreign.java_method_call(java_obj, "query", "SELECT * FROM users")
```

## Best Practices

### Memory Safety

1. **Never use raw pointers** for database operations
2. **Always use the provided handles** for resources
3. **Let automatic cleanup work** - don't manually free resources unless necessary
4. **Use structured error handling** with proper resource cleanup

### Performance Optimization

1. **Batch operations** when possible
2. **Reuse connections** instead of creating new ones
3. **Use prepared statements** for repeated queries
4. **Stream large result sets** rather than loading all at once

### Cross-Language Interaction

1. **Prefer using native APIs** when staying within one language
2. **Use Magic for interop** when crossing language boundaries
3. **Maintain consistent data types** across language boundaries
4. **Verify data integrity** when moving between languages

## Common Pitfalls

1. ❌ **Storing raw pointers**: Use handles instead
2. ❌ **Manual resource cleanup**: Let automatic cleanup handle it
3. ❌ **Ignoring errors**: Always handle errors and ensure resources are cleaned up
4. ❌ **Type mismatches**: Be careful with data type conversion between languages

## Examples

### Complete Mojo Example

```mojo
from shared.interfaces import DBInterface
from magic import interop

fn process_users() raises:
    var db = mojo.database_connector.DBConnector("postgresql://localhost:5432/mydb")
    db.connect()
    
    # Safe query execution
    let results = db.query("SELECT id, name FROM users")
    
    # Process results
    for i in range(results.get_row_count()):
        let id = results.get_value(i, 0)
        let name = results.get_value(i, 1)
        print("User: " + name + " (ID: " + id + ")")
    
    # No manual cleanup needed
    # Resources freed when variables go out of scope
```

## Testing Cross-Language Communication

See the integration tests in `tests/integration/cross_language_test.mojo` for examples of testing cross-language compatibility. 