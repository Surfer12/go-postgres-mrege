package vertex

import (
	"context"
	"fmt"
	"os"

	aiplatform "cloud.google.com/go/aiplatform/apiv1"
	"cloud.google.com/go/aiplatform/apiv1/aiplatformpb"
	"google.golang.org/protobuf/types/known/structpb"
)

// Config holds Vertex AI configuration
type Config struct {
	ProjectID  string
	Region     string
	EndpointID string
}

// Client wraps the Vertex AI client
type Client struct {
	config         Config
	endpointClient *aiplatform.EndpointClient
}

// NewClient creates a new Vertex AI client
func NewClient(ctx context.Context, config Config) (*Client, error) {
	// Use environment variables if config values are empty
	if config.ProjectID == "" {
		config.ProjectID = os.Getenv("PROJECT_ID")
	}
	if config.Region == "" {
		config.Region = os.Getenv("REGION")
	}
	if config.EndpointID == "" {
		config.EndpointID = os.Getenv("ENDPOINT_ID")
	}

	// Validate config
	if config.ProjectID == "" || config.Region == "" || config.EndpointID == "" {
		return nil, fmt.Errorf("missing required configuration: PROJECT_ID, REGION, or ENDPOINT_ID")
	}

	// Create client
	endpointClient, err := aiplatform.NewEndpointClient(ctx, aiplatform.ClientOptions{
		Region: config.Region,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create Vertex AI endpoint client: %w", err)
	}

	return &Client{
		config:         config,
		endpointClient: endpointClient,
	}, nil
}

// Predict sends instances to Vertex AI for prediction
func (c *Client) Predict(ctx context.Context, instances []map[string]interface{}) ([]map[string]interface{}, error) {
	// Convert instances to StructPb format
	instanceValues := make([]*structpb.Value, 0, len(instances))
	for _, instance := range instances {
		value, err := structpb.NewValue(instance)
		if err != nil {
			return nil, fmt.Errorf("failed to convert instance to structpb.Value: %w", err)
		}
		instanceValues = append(instanceValues, value)
	}

	// Create prediction request
	req := &aiplatformpb.PredictRequest{
		Endpoint: fmt.Sprintf("projects/%s/locations/%s/endpoints/%s",
			c.config.ProjectID, c.config.Region, c.config.EndpointID),
		Instances: instanceValues,
	}

	// Call Vertex AI Predict API
	resp, err := c.endpointClient.Predict(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("failed to get prediction: %w", err)
	}

	// Convert the predictions back to Go maps
	var predictions []map[string]interface{}
	for _, prediction := range resp.Predictions {
		p, err := prediction.AsMap()
		if err != nil {
			return nil, fmt.Errorf("failed to convert prediction to map: %w", err)
		}
		predictions = append(predictions, p)
	}

	return predictions, nil
}

// Close closes the underlying client
func (c *Client) Close() error {
	if c.endpointClient != nil {
		return c.endpointClient.Close()
	}
	return nil
}