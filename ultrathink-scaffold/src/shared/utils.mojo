"""
# Common utilities for database operations
# Focus on memory safety and cross-language compatibility

from magic import interop

struct Result:
    """
    Memory-safe result container for database queries.
    Automatically manages resource cleanup.
    """
    var result_handle: UInt64
    
    fn __init__(inout self, result_handle: UInt64):
        self.result_handle = result_handle
    
    fn get_row_count(self) -> Int:
        """Get number of rows in result set (memory safe)."""
        return interop.get_row_count(self.result_handle)
    
    fn get_column_count(self) -> Int:
        """Get number of columns in result set (memory safe)."""
        return interop.get_column_count(self.result_handle)
    
    fn get_value(self, row: Int, column: Int) -> String:
        """Safely access result data without direct memory manipulation."""
        return interop.get_result_value(self.result_handle, row, column)
    
    fn __del__(owned self):
        """Automatic resource cleanup when result goes out of scope."""
        if self.result_handle != 0:
            interop.free_result(self.result_handle)

# User data structure with memory-safe implementation
struct User:
    var id: Int
    var username: String
    var email: String
    
    fn __init__(inout self, id: Int = 0, username: String = "", email: String = ""):
        self.id = id
        self.username = username
        self.email = email
    
    # Safe serialization for cross-language interoperability
    fn to_handle(self) -> UInt64:
        """Convert to interoperable handle (memory safe)."""
        return interop.create_user_handle(self.id, self.username, self.email)
        
    @staticmethod
    fn from_handle(handle: UInt64) -> User:
        """Create User from interoperable handle (memory safe)."""
        var user = User()
        interop.extract_user_data(handle, user.id, user.username, user.email)
        interop.free_handle(handle)  # Automatically free the handle
        return user 