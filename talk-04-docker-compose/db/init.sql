CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO items (name, description) VALUES
    ('Docker Compose Basics', 'Learn how services, networks, and volumes work together.'),
    ('Gin API Endpoint', 'A starter item served from the Go API.'),
    ('Redis Cache Demo', 'Use Redis to cache item lookups and track hit/miss statistics.');

CREATE INDEX idx_items_name ON items(name);
