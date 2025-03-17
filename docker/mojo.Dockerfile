FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Mojo
RUN curl -fsSL https://get.modular.com | MODULAR_AUTH=mut_ad2b683e39ae480a9c3f78935e24fdb4 sh -
RUN modular install mojo

# Set environment variables
ENV MODULAR_HOME="/root/.modular"
ENV PATH="$MODULAR_HOME/pkg/packages.modular.com_mojo/bin:$PATH"

# Install Python dependencies for Mojo
RUN pip3 install \
    grpcio \
    grpcio-tools \
    protobuf \
    psycopg2-binary

# Set working directory
WORKDIR /app

# Copy proto file
COPY proto/user.proto /app/proto/

# Generate Python code from proto file
RUN mkdir -p /app/generated
RUN python3 -m grpc_tools.protoc \
    -I/app/proto \
    --python_out=/app/generated \
    --grpc_python_out=/app/generated \
    /app/proto/user.proto

# Copy Mojo source
COPY mojo/db_service.mojo /app/

# Create symbolic links so Mojo can find the generated modules
RUN cd /app/generated && \
    touch __init__.py && \
    ln -s /app/generated/user_pb2.py /app/user_pb2.py && \
    ln -s /app/generated/user_pb2_grpc.py /app/user_pb2_grpc.py

# Expose gRPC port
EXPOSE 50051

# Run the Mojo DB service
CMD ["mojo", "run", "db_service.mojo"]