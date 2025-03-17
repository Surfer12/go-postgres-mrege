# Polyglot Architecture Project Guide

## Build & Run Commands
- Go server: `go run main.go server` (legacy mode)
- Go API Gateway: `go run main.go proxy` (proxy to Java service)
- Run examples: `go run main.go`
- Full polyglot setup: `docker-compose -f docker/docker-compose.yml up`
- Java service: `cd java && ./mvnw spring-boot:run`
- Build Go binary: `go build -o app`
- Test Go package: `go test ./path/to/package`
- Test all Go packages: `go test ./...`
- Run with race detection: `go test -race ./...`
- Format Go code: `go fmt ./...`
- Lint Go code: `golangci-lint run`
- Java tests: `cd java && ./mvnw test`
- Java lint: `cd java && ./mvnw checkstyle:check`

## Code Style Guidelines
- **Go Imports**: Group std lib, external, internal packages with blank line separators
- **Error Handling**: Always wrap errors with context using `fmt.Errorf("context: %w", err)`
- **Variable Naming**: Use camelCase for variables, PascalCase for exported items
- **Function Structure**: Put error handling immediately after function calls
- **Database**: Use parameterized queries to prevent SQL injection
- **JSON Tags**: All model structs should have proper JSON struct tags
- **Error Returns**: Return early on errors
- **Documentation**: Document all exported functions and types
- **Package Structure**: Maintain consistent package organization (api, db, models, vertex)
- **Context Usage**: Pass context to external API calls (db, HTTP, Vertex AI)
- **Java Generics**: Use generic parameters for maximum code reuse
- **Mojo Performance**: Implement performance-critical operations using SIMD optimizations
- **Protocol Buffers**: Maintain compatibility between language implementations