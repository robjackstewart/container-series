CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (name, email) VALUES
    ('Ada Lovelace', 'ada@example.com'),
    ('Grace Hopper', 'grace@example.com'),
    ('Margaret Hamilton', 'margaret@example.com')
ON CONFLICT (email) DO NOTHING;
