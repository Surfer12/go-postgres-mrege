graph LR
    A[Main Application] --> B[User Module]
    A --> C[Product Module]
    B --> D[Database Library]
    C --> D
    B --> E[Authentication Library]
    C --> F[Payment Gateway]
    B --> L[Logging Library]
    C --> M[Analytics Library] 