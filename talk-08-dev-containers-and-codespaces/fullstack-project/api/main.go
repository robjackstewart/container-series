package main

import (
    "context"
    "database/sql"
    "encoding/json"
    "log"
    "net/http"
    "os"
    "sync"
    "time"

    _ "github.com/lib/pq"
)

type User struct {
    ID        int       `json:"id"`
    Name      string    `json:"name"`
    Email     string    `json:"email"`
    CreatedAt time.Time `json:"created_at"`
}

type createUserRequest struct {
    Name  string `json:"name"`
    Email string `json:"email"`
}

type app struct {
    db     *sql.DB
    mu     sync.Mutex
    users  []User
    nextID int
}

func main() {
    application := &app{
        users: []User{
            {ID: 1, Name: "Ada Lovelace", Email: "ada@example.com", CreatedAt: time.Now().UTC()},
            {ID: 2, Name: "Grace Hopper", Email: "grace@example.com", CreatedAt: time.Now().UTC()},
        },
        nextID: 3,
    }

    if db := connectDB(); db != nil {
        application.db = db
        defer db.Close()
    }

    mux := http.NewServeMux()
    mux.HandleFunc("/health", application.handleHealth)
    mux.HandleFunc("/users", application.handleUsers)

    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    log.Printf("Go API listening on :%s", port)
    if err := http.ListenAndServe(":"+port, logRequest(mux)); err != nil {
        log.Fatal(err)
    }
}

func connectDB() *sql.DB {
    databaseURL := os.Getenv("DATABASE_URL")
    if databaseURL == "" {
        log.Println("DATABASE_URL not set; using in-memory users")
        return nil
    }

    db, err := sql.Open("postgres", databaseURL)
    if err != nil {
        log.Printf("database open failed: %v", err)
        return nil
    }

    ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
    defer cancel()

    if err := db.PingContext(ctx); err != nil {
        log.Printf("database ping failed: %v; using in-memory users", err)
        _ = db.Close()
        return nil
    }

    log.Println("connected to PostgreSQL")
    return db
}

func (a *app) handleHealth(w http.ResponseWriter, _ *http.Request) {
    backend := "memory"
    if a.db != nil {
        backend = "postgres"
    }

    writeJSON(w, http.StatusOK, map[string]any{
        "status":  "ok",
        "backend": backend,
    })
}

func (a *app) handleUsers(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case http.MethodGet:
        a.listUsers(w)
    case http.MethodPost:
        a.createUser(w, r)
    default:
        w.Header().Set("Allow", "GET, POST")
        writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
    }
}

func (a *app) listUsers(w http.ResponseWriter) {
    if a.db != nil {
        ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
        defer cancel()

        rows, err := a.db.QueryContext(ctx, `SELECT id, name, email, created_at FROM users ORDER BY id`)
        if err == nil {
            defer rows.Close()

            users := []User{}
            for rows.Next() {
                var user User
                if scanErr := rows.Scan(&user.ID, &user.Name, &user.Email, &user.CreatedAt); scanErr != nil {
                    writeJSON(w, http.StatusInternalServerError, map[string]string{"error": scanErr.Error()})
                    return
                }
                users = append(users, user)
            }

            if rowsErr := rows.Err(); rowsErr == nil {
                writeJSON(w, http.StatusOK, map[string]any{"users": users})
                return
            }
        }
    }

    a.mu.Lock()
    defer a.mu.Unlock()
    writeJSON(w, http.StatusOK, map[string]any{"users": a.users})
}

func (a *app) createUser(w http.ResponseWriter, r *http.Request) {
    var req createUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON body"})
        return
    }

    if req.Name == "" || req.Email == "" {
        writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name and email are required"})
        return
    }

    if a.db != nil {
        ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
        defer cancel()

        user := User{}
        err := a.db.QueryRowContext(
            ctx,
            `INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at`,
            req.Name,
            req.Email,
        ).Scan(&user.ID, &user.Name, &user.Email, &user.CreatedAt)
        if err == nil {
            writeJSON(w, http.StatusCreated, user)
            return
        }

        writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
        return
    }

    a.mu.Lock()
    defer a.mu.Unlock()

    user := User{
        ID:        a.nextID,
        Name:      req.Name,
        Email:     req.Email,
        CreatedAt: time.Now().UTC(),
    }
    a.users = append(a.users, user)
    a.nextID++

    writeJSON(w, http.StatusCreated, user)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    if err := json.NewEncoder(w).Encode(payload); err != nil {
        log.Printf("response encode failed: %v", err)
    }
}

func logRequest(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        log.Printf("%s %s", r.Method, r.URL.Path)
        next.ServeHTTP(w, r)
    })
}
