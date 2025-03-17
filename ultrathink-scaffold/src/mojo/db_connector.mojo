from collections import Handle

# Opaque handle types that completely hide implementation details
struct ConnectionHandle(Handle):
    """Opaque handle for database connections that hides implementation details."""
    var id: Int
    
    fn __init__(inout self, connection_id: Int):
        self.id = connection_id
    
    fn __del__(owned self):
        if self.id > 0:
            interop.close_connection(self.id)

struct ResultHandle(Handle):
    """Opaque handle for query results that hides implementation details."""
    var id: Int
    
    fn __init__(inout self, result_id: Int):
        self.id = result_id
    
    fn __del__(owned self):
        if self.id > 0:
            interop.free_result(self.id)

# Safe interop module that abstracts away all unsafe operations
module interop:
    @staticmethod
    fn create_connection(conn_string: String) -> Int:
        """Creates a database connection and returns a safe handle ID."""
        # Implementation is hidden and managed by the interop layer
        return _safe_create_connection(conn_string)
    
    @staticmethod
    fn close_connection(conn_id: Int):
        """Safely closes a connection by handle ID."""
        _safe_close_connection(conn_id)
    
    @staticmethod
    fn execute_query(conn_id: Int, query: String) -> Int:
        """Executes a query and returns a safe result handle ID."""
        return _safe_execute_query(conn_id, query)
    
    @staticmethod
    fn free_result(result_id: Int):
        """Safely frees a result by handle ID."""
        _safe_free_result(result_id)
    
    @staticmethod
    fn get_row_count(result_id: Int) -> Int:
        """Gets row count from a result handle."""
        return _safe_get_row_count(result_id)
    
    @staticmethod
    fn get_value(result_id: Int, row: Int, col: Int) -> String:
        """Gets a value from a result handle."""
        return _safe_get_value(result_id, row, col)

# External implementations (hidden from user code)
@external
fn _safe_create_connection(conn_string: String) -> Int

@external
fn _safe_close_connection(conn_id: Int)

@external
fn _safe_execute_query(conn_id: Int, query: String) -> Int

@external
fn _safe_free_result(result_id: Int)

@external
fn _safe_get_row_count(result_id: Int) -> Int

@external
fn _safe_get_value(result_id: Int, row: Int, col: Int) -> String

struct DBConnector:
    """Memory-safe database connector using handle-based design and RAII principles."""
    var handle: ConnectionHandle
    var connected: Bool
    
    fn __init__(inout self, conn_string: String):
        """Constructor initializes with a disconnected state."""
        self.handle = ConnectionHandle(0)
        self.connected = False
        self.conn_string = conn_string
    
    var conn_string: String
    
    fn connect(inout self) raises:
        """Safely connect to the database."""
        if self.connected:
            return
            
        let conn_id = interop.create_connection(self.conn_string)
        if conn_id <= 0:
            raise Error("Failed to connect to database")
            
        self.handle = ConnectionHandle(conn_id)
        self.connected = True
    
    fn query(self, sql: String) raises -> QueryResult:
        """Execute a query and return a safe result wrapper."""
        if not self.connected:
            raise Error("Not connected to database")
            
        let result_id = interop.execute_query(self.handle.id, sql)
        if result_id <= 0:
            raise Error("Query execution failed")
            
        return QueryResult(ResultHandle(result_id))
    
    # Destructor automatically handles cleanup through the ConnectionHandle

struct QueryResult:
    """Safe wrapper for query results with no direct pointer manipulation."""
    var handle: ResultHandle
    
    fn __init__(inout self, result_handle: ResultHandle):
        self.handle = result_handle
    
    fn get_row_count(self) -> Int:
        """Safely get the number of rows in the result."""
        return interop.get_row_count(self.handle.id)
    
    fn get_value(self, row: Int, col: Int) raises -> String:
        """Safely get a value from the result set with bounds checking."""
        if row < 0 or row >= self.get_row_count():
            raise Error("Row index out of bounds")
            
        return interop.get_value(self.handle.id, row, col)
    
    # No need for explicit cleanup - ResultHandle destructor handles it

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