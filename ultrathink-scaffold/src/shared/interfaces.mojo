"""
# Common interfaces for database connectivity
# Designed for memory safety and interoperability

from magic import interop

trait DBInterface:
    """Interface for database connections with memory safety guarantees."""
    
    fn connect(inout self) raises -> Bool:
        """Connect to database with safety checks."""
        pass
        
    fn disconnect(inout self) raises -> Bool:
        """Safely disconnect from database."""
        pass
        
    fn query(self, sql: String) raises -> Result:
        """Execute query with memory-safe result handling."""
        pass
        
    fn execute(self, sql: String) raises -> Int:
        """Execute non-query SQL with safety guarantees."""
        pass

struct Result:
    """Memory-safe result wrapper that manages its own lifecycle."""
    var handle: UInt64
    
    fn __init__(inout self, handle: UInt64):
        self.handle = handle
    
    fn get_row_count(self) -> Int:
        return interop.get_row_count(self.handle)
    
    fn get_column_count(self) -> Int:
        return interop.get_column_count(self.handle)
    
    fn get_value(self, row: Int, col: Int) -> String:
        return interop.get_value(self.handle, row, col)
    
    fn __del__(owned self):
        """Automatic cleanup when result is no longer needed."""
        if self.handle != 0:
            interop.free_result(self.handle)

# Exception type for database errors
struct DBError:
    """Database error with safe string handling."""
    var message: String
    var code: Int
    
    fn __init__(inout self, message: String, code: Int = -1):
        self.message = message
        self.code = code
""" 