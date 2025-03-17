FROM golang:1.21 AS build

WORKDIR /app

# Copy Go module files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY api/ ./api/
COPY main.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o app main.go

# Runtime stage
FROM alpine:3.18

# Install CA certificates
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy the binary
COPY --from=build /app/app .

# Expose the port
EXPOSE 8000

# Run the application
CMD ["./app", "server"]