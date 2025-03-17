from python import Python
import time

# User struct with type-safe implementation
struct User:
    var id: Int
    var username: String
    var email: String
    
    fn __init__(inout self, id: Int = 0, username: String = "", email: String = ""):
        self.id = id
        self.username = username
        self.email = email
    
    # Conversion to Python dictionary for serialization
    fn to_dict(self) -> PythonObject:
        let dict = Python.dict()
        dict["id"] = self.id
        dict["username"] = self.username
        dict["email"] = self.email
        return dict
    
    # SIMD-optimized string comparison for search operations
    fn matches(self, query: String) -> Bool:
        # Check if query appears in username or email
        # This could be optimized further with SIMD string search
        return self.username.find(query) >= 0 or self.email.find(query) >= 0

# Type-safe vector implementation for User collection
struct UserList:
    var users: DynamicVector[User]
    
    fn __init__(inout self):
        self.users = DynamicVector[User]()
    
    fn __init__(inout self, capacity: Int):
        self.users = DynamicVector[User](capacity)
    
    fn append(inout self, user: User):
        self.users.push_back(user)
    
    fn get(self, index: Int) -> User:
        return self.users[index]
    
    fn size(self) -> Int:
        return len(self.users)
    
    # SIMD-optimized batch operations
    fn filter_by_query(self, query: String) -> UserList:
        var result = UserList()
        
        # This can be parallelized with SIMD in more advanced implementation
        for i in range(len(self.users)):
            if self.users[i].matches(query):
                result.append(self.users[i])
        
        return result

# Database service implemented with type safety
struct DatabaseService:
    # Python database connection
    var conn: PythonObject
    var cursor: PythonObject
    
    fn __init__(inout self):
        # Import psycopg2 Python module
        let psycopg2 = Python.import_module("psycopg2")
        
        # Connection parameters - these would be configurable in production
        let host = "postgres-db"  # Docker service name
        let port = 5432
        let user = "postgres"
        let password = "postgres"
        let dbname = "userdb"
        
        # Connection string
        let conn_str = "host=" + host + " port=" + String(port) + 
                      " dbname=" + dbname + " user=" + user + 
                      " password=" + password + " sslmode=disable"
        
        try:
            # Connect to PostgreSQL
            self.conn = psycopg2.connect(conn_str)
            self.cursor = self.conn.cursor()
            print("Successfully connected to PostgreSQL database")
            
            # Initialize the database schema
            self._init_schema()
            
        except:
            print("Error: Could not connect to PostgreSQL database")
            raise Error("Database connection failed")
    
    fn _init_schema(self):
        # Create users table if it doesn't exist
        let create_table_query = """
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(255) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL
            )
        """
        
        try:
            self.cursor.execute(create_table_query)
            self.conn.commit()
            print("Database schema initialized")
        except:
            print("Error: Could not initialize database schema")
            self.conn.rollback()
            raise Error("Schema initialization failed")
    
    fn __del__(owned self):
        # Ensure database resources are properly released
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        print("Database connection closed")
    
    # Create a new user
    fn create_user(self, username: String, email: String) raises -> Int:
        # Validate input
        if len(username) == 0 or len(email) == 0:
            raise Error("Username and email cannot be empty")
        
        let query = "INSERT INTO users (username, email) VALUES (%s, %s) RETURNING id"
        
        try:
            self.cursor.execute(query, (username, email))
            let id = self.cursor.fetchone()[0]
            self.conn.commit()
            return id
        except:
            self.conn.rollback()
            raise Error("Failed to create user")
    
    # Get user by ID
    fn get_user_by_id(self, id: Int) raises -> User:
        let query = "SELECT id, username, email FROM users WHERE id = %s"
        
        try:
            self.cursor.execute(query, (id,))
            let row = self.cursor.fetchone()
            
            if not row:
                raise Error("User not found")
            
            return User(row[0], row[1], row[2])
        except:
            raise Error("Failed to get user by ID")
    
    # Get all users
    fn get_all_users(self) raises -> UserList:
        let query = "SELECT id, username, email FROM users"
        
        try:
            self.cursor.execute(query)
            let rows = self.cursor.fetchall()
            
            var users = UserList(len(rows))
            for i in range(len(rows)):
                let row = rows[i]
                users.append(User(row[0], row[1], row[2]))
            
            return users
        except:
            raise Error("Failed to get all users")
    
    # Get users with pagination
    fn get_users(self, page_size: Int, page_number: Int) raises -> UserList:
        # Implement pagination with offset
        let offset = (page_number - 1) * page_size
        let query = "SELECT id, username, email FROM users ORDER BY id LIMIT %s OFFSET %s"
        
        try:
            self.cursor.execute(query, (page_size, offset))
            let rows = self.cursor.fetchall()
            
            var users = UserList(len(rows))
            for i in range(len(rows)):
                let row = rows[i]
                users.append(User(row[0], row[1], row[2]))
            
            return users
        except:
            raise Error("Failed to get users with pagination")
    
    # Get total user count
    fn get_user_count(self) raises -> Int:
        let query = "SELECT COUNT(*) FROM users"
        
        try:
            self.cursor.execute(query)
            let count = self.cursor.fetchone()[0]
            return count
        except:
            raise Error("Failed to get user count")
    
    # Update a user
    fn update_user(self, id: Int, username: String, email: String) raises -> Bool:
        # Validate input
        if len(username) == 0 or len(email) == 0:
            raise Error("Username and email cannot be empty")
        
        let query = "UPDATE users SET username = %s, email = %s WHERE id = %s"
        
        try:
            self.cursor.execute(query, (username, email, id))
            let rows_affected = self.cursor.rowcount
            self.conn.commit()
            
            return rows_affected > 0
        except:
            self.conn.rollback()
            raise Error("Failed to update user")
    
    # Delete a user
    fn delete_user(self, id: Int) raises -> Bool:
        let query = "DELETE FROM users WHERE id = %s"
        
        try:
            self.cursor.execute(query, (id,))
            let rows_affected = self.cursor.rowcount
            self.conn.commit()
            
            return rows_affected > 0
        except:
            self.conn.rollback()
            raise Error("Failed to delete user")

# gRPC Server implementation
struct GrpcServer:
    var db_service: DatabaseService
    var server: PythonObject
    
    fn __init__(inout self):
        self.db_service = DatabaseService()
        
        # Import gRPC modules
        let grpc = Python.import_module("grpc")
        let concurrent = Python.import_module("concurrent.futures")
        
        # Import generated gRPC code
        let user_pb2 = Python.import_module("user_pb2")
        let user_pb2_grpc = Python.import_module("user_pb2_grpc")
        
        # Create servicer class with Python code
        let servicer_code = """
class UserServicer:
    def __init__(self, mojo_handler):
        self.mojo_handler = mojo_handler
    
    def GetUser(self, request, context):
        return self.mojo_handler("GetUser", request, context)
    
    def ListUsers(self, request, context):
        return self.mojo_handler("ListUsers", request, context)
    
    def CreateUser(self, request, context):
        return self.mojo_handler("CreateUser", request, context)
    
    def UpdateUser(self, request, context):
        return self.mojo_handler("UpdateUser", request, context)
    
    def DeleteUser(self, request, context):
        return self.mojo_handler("DeleteUser", request, context)
"""
        
        # Execute Python code to define the servicer
        let globals = Python.globals()
        let locals = Python.dict()
        Python.execute(servicer_code, globals, locals)
        let UserServicer = locals["UserServicer"]
        
        # Create gRPC server
        self.server = grpc.server(concurrent.ThreadPoolExecutor(max_workers=10))
        
        # Create servicer
        let servicer = UserServicer(PythonObject(self._handle_grpc_request))
        
        # Add servicer to server
        user_pb2_grpc.add_UserServiceServicer_to_server(servicer, self.server)
        
        # Listen on port 50051
        self.server.add_insecure_port("[::]:50051")
    
    # Start the server
    fn start(self):
        self.server.start()
        print("Mojo gRPC server started on port 50051")
        
        # Keep the server running
        try:
            while True:
                time.sleep(86400)  # Sleep for a day
        except:
            self.stop()
    
    # Stop the server
    fn stop(self):
        self.server.stop(0)
        print("Mojo gRPC server stopped")
    
    # Handle gRPC requests
    fn _handle_grpc_request(self, method: PythonObject, request: PythonObject, context: PythonObject) -> PythonObject:
        let method_str = String(method)
        
        # Import gRPC modules
        let grpc = Python.import_module("grpc")
        let user_pb2 = Python.import_module("user_pb2")
        
        # Handle request based on method
        try:
            if method_str == "GetUser":
                return self._handle_get_user(request, context, user_pb2, grpc)
            elif method_str == "ListUsers":
                return self._handle_list_users(request, context, user_pb2, grpc)
            elif method_str == "CreateUser":
                return self._handle_create_user(request, context, user_pb2, grpc)
            elif method_str == "UpdateUser":
                return self._handle_update_user(request, context, user_pb2, grpc)
            elif method_str == "DeleteUser":
                return self._handle_delete_user(request, context, user_pb2, grpc)
            else:
                context.set_code(grpc.StatusCode.UNIMPLEMENTED)
                context.set_details("Method not implemented")
                return user_pb2.UserResponse()
        except:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details("Internal server error")
            
            if method_str == "DeleteUser":
                return user_pb2.DeleteUserResponse()
            else:
                return user_pb2.UserResponse()
    
    # Handle GetUser request
    fn _handle_get_user(self, request: PythonObject, context: PythonObject, 
                       user_pb2: PythonObject, grpc: PythonObject) -> PythonObject:
        try:
            let user = self.db_service.get_user_by_id(request.id)
            
            let response = user_pb2.UserResponse()
            response.user.id = user.id
            response.user.username = user.username
            response.user.email = user.email
            
            return response
        except:
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details("User not found")
            return user_pb2.UserResponse()
    
    # Handle ListUsers request
    fn _handle_list_users(self, request: PythonObject, context: PythonObject, 
                         user_pb2: PythonObject, grpc: PythonObject) -> PythonObject:
        try:
            var page_size = 10
            var page_number = 1
            
            if request.page_size > 0:
                page_size = request.page_size
            
            if request.page_number > 0:
                page_number = request.page_number
            
            let users = self.db_service.get_users(page_size, page_number)
            let count = self.db_service.get_user_count()
            
            let response = user_pb2.ListUsersResponse()
            response.total_count = count
            
            for i in range(users.size()):
                let user = users.get(i)
                let pb_user = response.users.add()
                pb_user.id = user.id
                pb_user.username = user.username
                pb_user.email = user.email
            
            return response
        except:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details("Failed to list users")
            return user_pb2.ListUsersResponse()
    
    # Handle CreateUser request
    fn _handle_create_user(self, request: PythonObject, context: PythonObject, 
                          user_pb2: PythonObject, grpc: PythonObject) -> PythonObject:
        try:
            let username = String(request.username)
            let email = String(request.email)
            
            let id = self.db_service.create_user(username, email)
            
            let response = user_pb2.UserResponse()
            response.user.id = id
            response.user.username = username
            response.user.email = email
            
            return response
        except:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details("Failed to create user")
            return user_pb2.UserResponse()
    
    # Handle UpdateUser request
    fn _handle_update_user(self, request: PythonObject, context: PythonObject, 
                          user_pb2: PythonObject, grpc: PythonObject) -> PythonObject:
        try:
            let id = request.id
            let username = String(request.username)
            let email = String(request.email)
            
            let success = self.db_service.update_user(id, username, email)
            
            if not success:
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details("User not found")
                return user_pb2.UserResponse()
            
            let response = user_pb2.UserResponse()
            response.user.id = id
            response.user.username = username
            response.user.email = email
            
            return response
        except:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details("Failed to update user")
            return user_pb2.UserResponse()
    
    # Handle DeleteUser request
    fn _handle_delete_user(self, request: PythonObject, context: PythonObject, 
                          user_pb2: PythonObject, grpc: PythonObject) -> PythonObject:
        try:
            let id = request.id
            let success = self.db_service.delete_user(id)
            
            let response = user_pb2.DeleteUserResponse()
            
            if not success:
                response.success = False
                response.message = "User not found"
                context.set_code(grpc.StatusCode.NOT_FOUND)
                context.set_details("User not found")
            else:
                response.success = True
                response.message = "User deleted successfully"
            
            return response
        except:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details("Failed to delete user")
            let response = user_pb2.DeleteUserResponse()
            response.success = False
            response.message = "Internal server error"
            return response

fn main():
    print("Starting Mojo Database Service")
    
    # Create and start gRPC server
    var server = GrpcServer()
    server.start()