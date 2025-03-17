from memory import unsafe
from collections import Handle

struct DBHandle(Handle):
    """Handle-based wrapper for database connection pointers.
       Prevents direct pointer manipulation."""
    var ptr: UnsafePointer[()]
    
    fn __init__(inout self, raw_ptr: UnsafePointer[()]):
        self.ptr = raw_ptr
    
    fn __del__(owned self):
        if self.ptr:
            _close_connection(self.ptr)

struct ResultHandle(Handle):
    """Safe handle for query results."""
    var ptr: UnsafePointer[()]
    
    fn __init__(inout self, raw_ptr: UnsafePointer[()]):
        self.ptr = raw_ptr
    
    fn __del__(owned self):
        if self.ptr:
            _free_result(self.ptr)

@external
fn _open_connection(conn_string: String) -> UnsafePointer[()]

@external
fn _close_connection(conn: UnsafePointer[()])

@external
fn _execute_query(conn: UnsafePointer[()], query: String) -> UnsafePointer[()]

@external
fn _free_result(result: UnsafePointer[()])

@external
fn _get_row_count(result: UnsafePointer[()]) -> Int

@external
fn _get_value(result: UnsafePointer[()], row: Int, col: Int) -> String

struct DBConnector:
    """Memory-safe database connector using RAII principles."""
    var handle: DBHandle
    var connected: Bool
    
    fn __init__(inout self, conn_string: String):
        """Constructor initializes with a disconnected state."""
        self.handle = DBHandle(UnsafePointer[()]())
        self.connected = False
    
    fn connect(inout self) raises:
        """Safely connect to the database."""
        if self.connected:
            return
            
        let raw_ptr = _open_connection(conn_string)
        if not raw_ptr:
            raise Error("Failed to connect to database")
            
        self.handle = DBHandle(raw_ptr)
        self.connected = True
    
    fn query(self, sql: String) raises -> QueryResult:
        """Execute a query and return a safe result wrapper."""
        if not self.connected:
            raise Error("Not connected to database")
            
        let result_ptr = _execute_query(self.handle.ptr, sql)
        if not result_ptr:
            raise Error("Query execution failed")
            
        return QueryResult(ResultHandle(result_ptr))
    
    fn __del__(owned self):
        """Destructor ensures connection is closed."""
        # Handle's destructor automatically closes the connection

struct QueryResult:
    """Safe wrapper for query results."""
    var handle: ResultHandle
    
    fn __init__(inout self, result_handle: ResultHandle):
        self.handle = result_handle
    
    fn get_row_count(self) -> Int:
        """Safely get the number of rows in the result."""
        return _get_row_count(self.handle.ptr)
    
    fn get_value(self, row: Int, col: Int) raises -> String:
        """Safely get a value from the result set with bounds checking."""
        if row < 0 or row >= self.get_row_count():
            raise Error("Row index out of bounds")
            
        return _get_value(self.handle.ptr, row, col)
    
    # No need for explicit cleanup - ResultHandle's destructor handles it

fn example_usage() raises:
    # Example of safe usage
    var db = DBConnector("postgresql://localhost:5432/mydb")
    
    try:
        db.connect()
        
        # Query users
        let users = db.query("SELECT id, username, email FROM users")
        print("Found " + str(users.get_row_count()) + " users")
        
        for i in range(users.get_row_count()):
            let id = users.get_value(i, 0)
            let username = users.get_value(i, 1)
            let email = users.get_value(i, 2)
            print("User: " + username + " (ID: " + id + ", Email: " + email + ")")
        
        # Query posts
        let posts = db.query("SELECT id, title FROM posts")
        print("Found " + str(posts.get_row_count()) + " posts")
        
        for i in range(posts.get_row_count()):
            let id = posts.get_value(i, 0)
            let title = posts.get_value(i, 1)
            print("Post: " + title + " (ID: " + id + ")")
            
    except e:
        print("Error: " + str(e))
        # Even with exception, db will be cleaned up automatically
    
    # No explicit cleanup needed - destructors handle cleanup 