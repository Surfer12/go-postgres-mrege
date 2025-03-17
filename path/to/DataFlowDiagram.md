graph LR
    A[User Input] --> B[Validation]
    B --> C[Data Processing]
    C --> D[Database Storage]
    D --> E[Data Retrieval]
    C --> N[Notification Processing]
    N --> O[Email Notification]
    N --> P[Push Notification]
    E --> F[Output] 