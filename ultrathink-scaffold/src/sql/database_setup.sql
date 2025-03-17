-- Database setup for memory-safe database connectors
-- Creates tables, indices, and sample data for testing

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create posts table with foreign key reference to users
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create comments table with foreign key references
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indices for better query performance
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);

-- Insert sample data for testing
-- Users
INSERT INTO users (username, email) VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com')
ON CONFLICT (username) DO NOTHING;

-- Posts
INSERT INTO posts (user_id, title, content)
SELECT u.id, 'First post by ' || u.username, 'This is sample content for testing the memory-safe database connectors.'
FROM users u
WHERE u.username = 'alice'
ON CONFLICT DO NOTHING;

INSERT INTO posts (user_id, title, content)
SELECT u.id, 'Second post by ' || u.username, 'More sample content for testing various database operations.'
FROM users u
WHERE u.username = 'bob'
ON CONFLICT DO NOTHING;

-- Comments
INSERT INTO comments (post_id, user_id, content)
SELECT p.id, u.id, 'Great post! Comment by ' || u.username
FROM posts p, users u
WHERE p.title LIKE 'First post%' AND u.username = 'bob'
ON CONFLICT DO NOTHING;

INSERT INTO comments (post_id, user_id, content)
SELECT p.id, u.id, 'Thanks for sharing! Comment by ' || u.username
FROM posts p, users u
WHERE p.title LIKE 'Second post%' AND u.username = 'charlie'
ON CONFLICT DO NOTHING;

-- Create views for common queries
CREATE OR REPLACE VIEW user_activity AS
SELECT 
    u.id AS user_id,
    u.username,
    u.email,
    COUNT(DISTINCT p.id) AS post_count,
    COUNT(DISTINCT c.id) AS comment_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY u.id, u.username, u.email;

CREATE OR REPLACE VIEW post_details AS
SELECT 
    p.id AS post_id,
    p.title,
    p.content,
    p.created_at,
    u.username AS author,
    COUNT(c.id) AS comment_count
FROM posts p
JOIN users u ON p.user_id = u.id
LEFT JOIN comments c ON p.id = c.post_id
GROUP BY p.id, p.title, p.content, p.created_at, u.username;

-- Create stored procedure example
CREATE OR REPLACE FUNCTION get_user_stats(p_username VARCHAR)
RETURNS TABLE (
    post_count BIGINT,
    comment_count BIGINT,
    last_activity TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT p.id) AS post_count,
        COUNT(DISTINCT c.id) AS comment_count,
        GREATEST(
            MAX(p.created_at),
            MAX(c.created_at)
        ) AS last_activity
    FROM users u
    LEFT JOIN posts p ON u.id = p.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    WHERE u.username = p_username;
END;
$$ LANGUAGE plpgsql;

-- Grant appropriate permissions (customize as needed)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO current_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO current_user; 