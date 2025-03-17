#!/bin/bash

# Build script for the database connector framework
# This builds all language connectors

set -e

echo "Building Database Connector Framework..."

# Build directories
mkdir -p build/{mojo,java,swift}

# Build Mojo connector
echo "Building Mojo connector..."
cd src/mojo
mojo build database_connector.mojo -o ../../build/mojo/database_connector
cd ../..

# Build Java connector
echo "Building Java connector..."
cd src/java
javac -d ../../build/java DatabaseConnector.java
cd ../..

# Build Swift connector
echo "Building Swift connector..."
cd src/swift
swiftc -emit-executable DatabaseConnector.swift -o ../../build/swift/database_connector
cd ../..

# Build integration tests
echo "Building integration tests..."
cd tests/integration
mojo build cross_language_test.mojo -o ../../build/cross_language_test
cd ../..

echo "Build completed successfully!"
echo "Binaries are available in the build/ directory" 