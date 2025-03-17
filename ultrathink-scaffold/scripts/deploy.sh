#!/bin/bash

# Deployment script for the database connector framework
# This deploys all language connectors to their respective environments

set -e

echo "Deploying Database Connector Framework..."

# Make sure we have a build first
if [ ! -d "build" ]; then
    echo "Build directory not found. Running build script first..."
    ./scripts/build.sh
fi

# Deploy directories
mkdir -p deploy/{mojo,java,swift}

# Deploy Mojo connector
echo "Deploying Mojo connector..."
cp build/mojo/database_connector deploy/mojo/
cp src/mojo/*.mojo deploy/mojo/

# Deploy Java connector
echo "Deploying Java connector..."
cp -r build/java/* deploy/java/
jar -cf deploy/java/database-connector.jar -C build/java .

# Deploy Swift connector
echo "Deploying Swift connector..."
cp build/swift/database_connector deploy/swift/
cp src/swift/*.swift deploy/swift/

# Deploy Magic and Max libraries
echo "Deploying libraries..."
mkdir -p deploy/lib/{magic,max}
cp -r lib/magic/* deploy/lib/magic/
cp -r lib/max/* deploy/lib/max/

# Deploy documentation
echo "Deploying documentation..."
mkdir -p deploy/docs
cp docs/*.md deploy/docs/

# Deploy integration tests
echo "Deploying integration tests..."
cp build/cross_language_test deploy/

echo "Deployment completed successfully!"
echo "Deployment artifacts are available in the deploy/ directory" 