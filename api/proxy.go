package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/gorilla/mux"
)

// UserServiceClient represents a client for the Java User Service
type UserServiceClient struct {
	BaseURL string
}

// NewUserServiceClient creates a new UserServiceClient
func NewUserServiceClient() *UserServiceClient {
	baseURL := os.Getenv("USER_SERVICE_URL")
	if baseURL == "" {
		baseURL = "http://localhost:8080"
	}
	
	return &UserServiceClient{BaseURL: baseURL}
}

// SetupProxyRoutes adds proxy routes to the router
func (s *Server) SetupProxyRoutes() {
	// Generic proxy handler for user service
	s.router.PathPrefix("/api/users").HandlerFunc(s.ProxyUserServiceHandler)
}

// ProxyUserServiceHandler forwards all requests to the Java User Service
func (s *Server) ProxyUserServiceHandler(w http.ResponseWriter, r *http.Request) {
	userService := NewUserServiceClient()
	
	// Extract path
	path := r.URL.Path
	if strings.HasPrefix(path, "/api") {
		path = strings.TrimPrefix(path, "/api")
	}
	
	// Build target URL
	targetURL := fmt.Sprintf("%s%s", userService.BaseURL, path)
	if r.URL.RawQuery != "" {
		targetURL = fmt.Sprintf("%s?%s", targetURL, r.URL.RawQuery)
	}
	
	// Create new request
	proxyReq, err := http.NewRequest(r.Method, targetURL, r.Body)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error creating proxy request: %v", err), http.StatusInternalServerError)
		return
	}
	
	// Copy headers
	for name, values := range r.Header {
		for _, value := range values {
			proxyReq.Header.Add(name, value)
		}
	}
	
	// Set content type for POST/PUT
	if r.Method == http.MethodPost || r.Method == http.MethodPut || r.Method == http.MethodPatch {
		proxyReq.Header.Set("Content-Type", "application/json")
	}
	
	// Send request
	client := &http.Client{}
	resp, err := client.Do(proxyReq)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error proxying request: %v", err), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()
	
	// Copy response headers
	for name, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(name, value)
		}
	}
	
	// Set status code
	w.WriteHeader(resp.StatusCode)
	
	// Copy response body
	io.Copy(w, resp.Body)
}

// Methods that integrate with existing API methods

// GetUserWithVertexAnalysis gets a user and analyzes with Vertex AI
func (s *Server) GetUserWithVertexAnalysis(w http.ResponseWriter, r *http.Request) {
	// Extract user ID from path
	vars := mux.Vars(r)
	userID := vars["id"]
	
	// Get user from Java service
	userService := NewUserServiceClient()
	resp, err := http.Get(fmt.Sprintf("%s/users/%s", userService.BaseURL, userID))
	if err != nil {
		http.Error(w, fmt.Sprintf("Error getting user: %v", err), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		// Forward the error
		w.WriteHeader(resp.StatusCode)
		io.Copy(w, resp.Body)
		return
	}
	
	// Read user data
	var userData map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&userData); err != nil {
		http.Error(w, "Error parsing user data", http.StatusInternalServerError)
		return
	}
	
	// Now use Vertex AI to analyze the user
	instances := []map[string]interface{}{
		{
			"user_data": userData,
			"analysis_type": "user_profile",
		},
	}
	
	// Perform prediction
	predictions, err := s.vertexClient.Predict(r.Context(), instances)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error analyzing user: %v", err), http.StatusInternalServerError)
		return
	}
	
	// Combine user data with predictions
	result := map[string]interface{}{
		"user_data": userData,
		"analysis": predictions[0],
	}
	
	// Return the combined result
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}