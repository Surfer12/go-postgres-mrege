package main

import (
	"context"
	"fmt"
	"log"
	"my-go-postgres-project/api"
	"my-go-postgres-project/db"
	"my-go-postgres-project/models"
	"my-go-postgres-project/vertex"
	"os"
)

func main() {
	// Determine which mode to run in
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "server":
			// Run the traditional server mode
			runServer()
		case "proxy":
			// Run the API Gateway proxy mode
			runProxy()
		case "polyglot":
			// Run the full polyglot setup
			log.Println("To run the full polyglot setup, use: docker-compose -f docker/docker-compose.yml up")
			log.Println("This will start Postgres, Mojo, Java, and Go services")
			os.Exit(0)
		default:
			// Example usage in development mode
			runExamples()
		}
	} else {
		// Default to examples
		runExamples()
	}
}

func runServer() {
	// Initialize the database connection
	dbConn, err := db.InitDB()
	if err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer dbConn.Close()

	// Initialize Vertex AI client
	vertexConfig := vertex.Config{
		ProjectID:  os.Getenv("PROJECT_ID"),
		Region:     os.Getenv("REGION"),
		EndpointID: os.Getenv("ENDPOINT_ID"),
	}

	vertexClient, err := vertex.NewClient(context.Background(), vertexConfig)
	if err != nil {
		log.Printf("Warning: Failed to initialize Vertex AI client: %v", err)
		log.Println("Continuing without Vertex AI integration...")
		// Continue without Vertex AI for development purposes
	} else {
		defer vertexClient.Close()
	}

	// Create API server
	server := api.NewServer(dbConn, vertexClient)

	// Get port from environment or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Fatal(server.Start(":" + port))
}

func runProxy() {
	// Initialize Vertex AI client for combined analysis
	vertexConfig := vertex.Config{
		ProjectID:  os.Getenv("PROJECT_ID"),
		Region:     os.Getenv("REGION"),
		EndpointID: os.Getenv("ENDPOINT_ID"),
	}

	vertexClient, err := vertex.NewClient(context.Background(), vertexConfig)
	if err != nil {
		log.Printf("Warning: Failed to initialize Vertex AI client: %v", err)
		log.Println("Continuing with proxy only, without Vertex AI integration...")
	} else {
		defer vertexClient.Close()
	}

	// Create API server with proxy setup
	server := api.NewServer(nil, vertexClient)
	
	// Configure proxy routes
	server.SetupProxyRoutes()

	// Get port from environment or use default
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000" // Use different default port for proxy mode
	}
	
	log.Printf("Starting API Gateway in proxy mode on port %s", port)
	log.Fatal(server.Start(":" + port))
}
}

func runExamples() {
	fmt.Println("===== Running example operations =====")
	
	// Initialize database connection
	dbConn, err := db.InitDB()
	if err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer dbConn.Close()
	
	// Example usage: Create a user
	newUser := models.User{
		Username: "testuser",
		Email:    "test@example.com",
	}

	createdUser, err := db.CreateUser(dbConn, newUser)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Created user: %+v\n", createdUser)

	// Example usage: Get a user by ID
	retrievedUser, err := db.GetUserByID(dbConn, createdUser.ID)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Retrieved user: %+v\n", retrievedUser)

	// Example usage: Update a user
	updatedUser := models.User{
		ID:       retrievedUser.ID,
		Username: "updateduser",
		Email:    "updated@example.com",
	}

	rowsAffected, err := db.UpdateUser(dbConn, updatedUser)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Rows affected by update: %d\n", rowsAffected)

	// Example usage: Get all users.
	allUsers, err := db.GetAllUsers(dbConn)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("All users: %+v\n", allUsers)

	// Example usage: Delete a user
	err = db.DeleteUser(dbConn, createdUser.ID)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("User deleted successfully")
	
	// Create a sample RCCT ThoughtNode structure
	sampleNode := models.ThoughtNode{
		ID:       "root-1",
		Content:  "Sample root thought node",
		NodeType: "understanding",
		Children: []*models.ThoughtNode{
			{
				ID:       "child-1",
				Content:  "Child thought exploration",
				NodeType: "exploration",
				Metrics: &models.NodeMetrics{
					Confidence: 0.85,
					Complexity: 0.65,
					Novelty:    0.72,
				},
			},
		},
		MetaAnalysis: "Meta-analysis of the thought process",
	}
	
	fmt.Printf("Sample RCCT ThoughtNode: %+v\n", sampleNode)
	
	// Show polyglot architecture information
	fmt.Println("\n===== Polyglot Architecture =====")
	fmt.Println("This project demonstrates a polyglot architecture with:")
	fmt.Println("1. Go: API Gateway and legacy Go DB implementation")
	fmt.Println("2. Mojo: High-performance database service with SIMD optimizations (gRPC)")
	fmt.Println("3. Java: Type-safe REST API with generic implementations")
	fmt.Println("4. Postgres: Relational database backend")
	fmt.Println("5. Vertex AI: Machine learning integration for user analysis")
	
	fmt.Println("\nTo run the polyglot architecture:")
	fmt.Println("docker-compose -f docker/docker-compose.yml up")
}
