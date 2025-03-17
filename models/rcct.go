package models

// ThoughtNode represents a node in the Recursive Cognitive Chain of Thought
type ThoughtNode struct {
	ID           string         `json:"id"`
	Content      string         `json:"content"`
	NodeType     string         `json:"node_type"` // understanding, analysis, exploration, solution, reflection
	Children     []*ThoughtNode `json:"children,omitempty"`
	MetaAnalysis string         `json:"meta_analysis,omitempty"`
	UserID       int            `json:"user_id,omitempty"`
	Metrics      *NodeMetrics   `json:"metrics,omitempty"`
}

// NodeMetrics contains measurement data for a ThoughtNode
type NodeMetrics struct {
	Confidence     float64 `json:"confidence"`
	Complexity     float64 `json:"complexity"`
	Novelty        float64 `json:"novelty"`
	CoherenceScore float64 `json:"coherence_score"`
}

// StructuredAnalysis represents the complete RCCT analysis
type StructuredAnalysis struct {
	Understanding      *ThoughtNode   `json:"understanding"`
	Analysis           *ThoughtNode   `json:"analysis"`
	Exploration        *ThoughtNode   `json:"exploration"`
	SolutionFormulation *ThoughtNode  `json:"solution_formulation"`
	Reflection         *ThoughtNode   `json:"reflection"`
	MetaObservations   []string       `json:"meta_observations,omitempty"`
	UserData           *User          `json:"user_data,omitempty"`
}

// PredictionRequest represents a request to the Vertex AI model
type PredictionRequest struct {
	Input       string            `json:"input"`
	UserContext *User             `json:"user_context,omitempty"`
	Parameters  map[string]string `json:"parameters,omitempty"`
}

// PredictionResponse represents a response from the Vertex AI model
type PredictionResponse struct {
	StructuredAnalysis *StructuredAnalysis `json:"structured_analysis"`
	RawPrediction      interface{}         `json:"raw_prediction,omitempty"`
}