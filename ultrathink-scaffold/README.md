# Multi-Language Database Connector Framework

A memory-safe, high-performance database connector framework with cross-language interoperability between Mojo, Java, and Swift.

## Project Overview

This project provides a consistent database connector API across three languages:

- **Mojo**: High-performance primary implementation
- **Java**: Full interoperability with Mojo
- **Swift**: Full interoperability with Mojo

All implementations prioritize memory safety without sacrificing performance, using handle-based API design instead of raw pointers.

## Key Features

- ✅ Memory safety guarantees 
- ✅ Cross-language interoperability
- ✅ High performance
- ✅ Automatic resource management
- ✅ Consistent API across languages

## Architecture

The project uses a layered design:

```
┌─────────────────────────────────────────────────────┐
│                  Application Layer                  │
└───────────────┬─────────────┬───────────────────────┘
                │             │                  
┌───────────────▼─┐ ┌─────────▼───────┐ ┌─────────────────┐
│  Mojo Connector │ │ Java Connector  │ │ Swift Connector │
└───────────┬─────┘ └────────┬────────┘ └────────┬────────┘
            │                │                   │         
┌───────────▼────────────────▼───────────────────▼────────┐
│                   Magic Interop Layer                    │
└──────────────────────────┬───────────────────────────────┘
                           │                         
┌──────────────────────────▼───────────────────────────────┐
│                  Database Drivers Layer                  │
└─────────────────────────────────────────────────────────┘
```

## Getting Started

### Prerequisites

- Mojo compiler
- Java JDK 11+
- Swift 5.5+
- PostgreSQL database

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/db-connector-framework.git

# Build all connectors
./scripts/build.sh
```

### Basic Usage - Mojo

```mojo
from mojo.database_connector import DBConnector

fn main() raises:
    var db = DBConnector("postgresql://localhost:5432/mydb")
    db.connect()
    
    let results = db.query("SELECT id, name FROM users")
    
    for i in range(results.get_row_count()):
        print(results.get_value(i, 0) + ": " + results.get_value(i, 1))
```

### Basic Usage - Java

```java
import com.example.db.DatabaseConnector;

public class Main {
    public static void main(String[] args) throws SQLException {
        try (DatabaseConnector db = new DatabaseConnector("postgresql://localhost:5432/mydb")) {
            db.connect();
            
            try (QueryResult results = db.query("SELECT id, name FROM users")) {
                for (int i = 0; i < results.getRowCount(); i++) {
                    System.out.println(results.getValue(i, 0) + ": " + results.getValue(i, 1));
                }
            }
        }
    }
}
```

### Basic Usage - Swift

```swift
import DatabaseConnector

func main() throws {
    let db = DatabaseConnector(connectionString: "postgresql://localhost:5432/mydb")
    try db.connect()
    
    let results = try db.query("SELECT id, name FROM users")
    
    for i in 0..<results.rowCount {
        print("\(results.getValue(row: i, column: 0)): \(results.getValue(row: i, column: 1))")
    }
}
```

## Memory Safety

Unlike traditional database connectors that often use raw pointers and manual memory management, this framework uses:

1. Handle-based APIs for all resources
2. Automatic resource cleanup through language features
3. Exception safety for proper cleanup on errors

See the [Memory Safety Guide](./docs/memory_safety_guide.md) for more details.

## Interoperability

For information on cross-language communication, see the [Interoperability Guide](./docs/interoperability_guide.md).

## License

This project is licensed under the MIT License - see the LICENSE file for details. 