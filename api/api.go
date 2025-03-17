package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"my-go-postgres-project/db"
	"my-go-postgres-project/models"
	"my-go-postgres-project/vertex"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

// Server represents the API server
type Server struct {
	router      *mux.Router
	dbConn      *sql.DB
	vertexClient *vertex.Client
}

// NewServer creates a new API server
func NewServer(dbConn *sql.DB, vertexClient *vertex.Client) *Server {
	s := &Server{
		router:      mux.NewRouter(),
		dbConn:      dbConn,
		vertexClient: vertexClient,
	}
	s.setupRoutes()
	return s
}

// setupRoutes configures all API routes
func (s *Server) setupRoutes() {
	// User management routes
	s.router.HandleFunc("/users", s.createUserHandler).Methods("POST")
	s.router.HandleFunc("/users", s.getAllUsersHandler).Methods("GET")
	s.router.HandleFunc("/users/{id}", s.getUserHandler).Methods("GET")
	s.router.HandleFunc("/users/{id}", s.updateUserHandler).Methods("PUT")
	s.router.HandleFunc("/users/{id}", s.deleteUserHandler).Methods("DELETE")

	// Vertex AI prediction route
	s.router.HandleFunc("/predict", s.predictHandler).Methods("POST")

	// Integration with RCCT models
	s.router.HandleFunc("/analyze", s.analyzeWithRCCTHandler).Methods("POST")
}

// Start starts the HTTP server
func (s *Server) Start(addr string) error {
	log.Printf("Server starting on %s", addr)
	return http.ListenAndServe(addr, s.router)
}

// User handlers

func (s *Server) createUserHandler(w http.ResponseWriter, r *http.Request) {
	var user models.User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	createdUser, err := db.CreateUser(s.dbConn, user)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(createdUser)
}

func (s *Server) getAllUsersHandler(w http.ResponseWriter, r *http.Request) {
	users, err := db.GetAllUsers(s.dbConn)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(users)
}

func (s *Server) getUserHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	user, err := db.GetUserByID(s.dbConn, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(user)
}

func (s *Server) updateUserHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	var user models.User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	user.ID = id

	_, err = db.UpdateUser(s.dbConn, user)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *Server) deleteUserHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid user ID", http.StatusBadRequest)
		return
	}

	err = db.DeleteUser(s.dbConn, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// Vertex AI prediction handler

func (s *Server) predictHandler(w http.ResponseWriter, r *http.Request) {
	// Parse request body
	var requestData struct {
		Instances []map[string]interface{} `json:"instances"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
		http.Error(w, "Request must be in JSON format with 'instances' key", http.StatusBadRequest)
		return
	}

	if len(requestData.Instances) == 0 {
		http.Error(w, "JSON must contain 'instances' key with at least one instance", http.StatusBadRequest)
		return
	}

	// Call Vertex AI for prediction
	predictions, err := s.vertexClient.Predict(context.Background(), requestData.Instances)
	if err != nil {
		http.Error(w, "Prediction failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Return the predictions
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"predictions": predictions,
	})
}

// Integration with RCCT models

type RCCTRequest struct {
	Input         string            `json:"input"`
	UserID        int               `json:"user_id"`
	ModelParams   map[string]string `json:"model_params,omitempty"`
	MetaAnalysis  bool              `json:"meta_analysis"`
}

type RCCTResponse struct {
	StructuredAnalysis map[string]interface{} `json:"structured_analysis"`
	Prediction         interface{}            `json:"prediction,omitempty"`
	MetaObservations   []string               `json:"meta_observations,omitempty"`
	UserData           *models.User           `json:"user_data,omitempty"`
}

func (s *Server) analyzeWithRCCTHandler(w http.ResponseWriter, r *http.Request) {
	// Parse request
	var requestData RCCTRequest
	if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
		http.Error(w, "Invalid request format: "+err.Error(), http.StatusBadRequest)
		return
	}

	// 1. Get user data if userID provided
	var userData *models.User
	if requestData.UserID > 0 {
		user, err := db.GetUserByID(s.dbConn, requestData.UserID)
		if err == nil {
			userData = &user
		}
	}

	// 2. Prepare data for Vertex AI prediction
	instances := []map[string]interface{}{
		{
			"text": requestData.Input,
			"parameters": map[string]interface{}{
				"meta_analysis": requestData.MetaAnalysis,
				"model_params":  requestData.ModelParams,
			},
		},
	}

	// 3. Get prediction from Vertex AI
	predictions, err := s.vertexClient.Predict(context.Background(), instances)
	if err != nil {
		http.Error(w, "Analysis failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// 4. Construct response
	response := RCCTResponse{
		StructuredAnalysis: map[string]interface{}{
			"understanding": map[string]interface{}{
				"key_components": []string{
					"Cognitive analysis using RCCT framework",
					"Integration of user data with AI predictions",
					"Meta-cognitive reflection on analysis process",
				},
			},
			"analysis": map[string]interface{}{
				"deep_analysis": "Performed structured analysis using integrated RCCT-Vertex pipeline",
			},
		},
		Prediction:       predictions[0],
		MetaObservations: []string{"Analysis completed using RCCT framework with Vertex AI"},
		UserData:         userData,
	}

	// Return the response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}