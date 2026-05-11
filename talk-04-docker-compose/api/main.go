package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type Config struct {
	Port        string
	DBHost      string
	DBPort      string
	DBUser      string
	DBPassword  string
	DBName      string
	RedisHost   string
	RedisPort   string
	RedisDB     int
	CacheTTL    time.Duration
	ShutdownTTL time.Duration
}

type Item struct {
	ID          int64     `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	CreatedAt   time.Time `json:"created_at"`
}

type createItemRequest struct {
	Name        string `json:"name" binding:"required"`
	Description string `json:"description"`
}

type App struct {
	db          *pgxpool.Pool
	redis       *redis.Client
	cacheHits   atomic.Uint64
	cacheMisses atomic.Uint64
	cacheTTL    time.Duration
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--healthcheck" {
		os.Exit(runHealthcheck())
	}

	cfg := loadConfig()

	if strings.EqualFold(os.Getenv("DEBUG"), "true") {
		gin.SetMode(gin.DebugMode)
	} else {
		gin.SetMode(gin.ReleaseMode)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	dbPool, err := connectPostgres(ctx, cfg)
	if err != nil {
		log.Fatalf("postgres connection failed: %v", err)
	}
	defer dbPool.Close()

	redisClient, err := connectRedis(ctx, cfg)
	if err != nil {
		log.Fatalf("redis connection failed: %v", err)
	}
	defer func() {
		if closeErr := redisClient.Close(); closeErr != nil {
			log.Printf("redis close error: %v", closeErr)
		}
	}()

	app := &App{
		db:       dbPool,
		redis:    redisClient,
		cacheTTL: cfg.CacheTTL,
	}

	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())
	router.GET("/health", app.healthHandler)
	router.GET("/items", app.listItems)
	router.POST("/items", app.createItem)
	router.GET("/items/:id", app.getItem)
	router.DELETE("/items/:id", app.deleteItem)
	router.GET("/cache-stats", app.cacheStats)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTTL)
		defer cancel()

		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("server shutdown error: %v", err)
		}
	}()

	log.Printf("api listening on %s", srv.Addr)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("server failed: %v", err)
	}

	log.Println("api stopped cleanly")
}

func loadConfig() Config {
	redisDB, err := strconv.Atoi(getEnv("REDIS_DB", "0"))
	if err != nil {
		redisDB = 0
	}

	return Config{
		Port:        getEnv("PORT", "8080"),
		DBHost:      getEnv("DB_HOST", "postgres"),
		DBPort:      getEnv("DB_PORT", "5432"),
		DBUser:      getEnv("DB_USER", "appuser"),
		DBPassword:  getEnv("DB_PASSWORD", "secretpassword"),
		DBName:      getEnv("DB_NAME", "itemsdb"),
		RedisHost:   getEnv("REDIS_HOST", "redis"),
		RedisPort:   getEnv("REDIS_PORT", "6379"),
		RedisDB:     redisDB,
		CacheTTL:    5 * time.Minute,
		ShutdownTTL: 10 * time.Second,
	}
}

func connectPostgres(ctx context.Context, cfg Config) (*pgxpool.Pool, error) {
	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable", cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName)
	poolConfig, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse postgres config: %w", err)
	}

	var pool *pgxpool.Pool
	for attempt := 1; attempt <= 10; attempt++ {
		pool, err = pgxpool.NewWithConfig(ctx, poolConfig)
		if err == nil {
			pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
			pingErr := pool.Ping(pingCtx)
			cancel()
			if pingErr == nil {
				return pool, nil
			}
			err = pingErr
			pool.Close()
		}

		if attempt < 10 {
			log.Printf("waiting for postgres (attempt %d/10): %v", attempt, err)
			time.Sleep(2 * time.Second)
		}
	}

	return nil, fmt.Errorf("postgres unavailable after retries: %w", err)
}

func connectRedis(ctx context.Context, cfg Config) (*redis.Client, error) {
	client := redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
		DB:   cfg.RedisDB,
	})

	var err error
	for attempt := 1; attempt <= 10; attempt++ {
		pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		_, err = client.Ping(pingCtx).Result()
		cancel()
		if err == nil {
			return client, nil
		}

		if attempt < 10 {
			log.Printf("waiting for redis (attempt %d/10): %v", attempt, err)
			time.Sleep(2 * time.Second)
		}
	}

	_ = client.Close()
	return nil, fmt.Errorf("redis unavailable after retries: %w", err)
}

func (a *App) healthHandler(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()

	dbStatus := "ok"
	if err := a.db.Ping(ctx); err != nil {
		dbStatus = err.Error()
	}

	redisStatus := "ok"
	if err := a.redis.Ping(ctx).Err(); err != nil {
		redisStatus = err.Error()
	}

	statusCode := http.StatusOK
	status := "ok"
	if dbStatus != "ok" || redisStatus != "ok" {
		statusCode = http.StatusServiceUnavailable
		status = "degraded"
	}

	c.JSON(statusCode, gin.H{
		"status": status,
		"services": gin.H{
			"postgres": dbStatus,
			"redis":    redisStatus,
		},
	})
}

func (a *App) listItems(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	rows, err := a.db.Query(ctx, `SELECT id, name, description, created_at FROM items ORDER BY id`)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "query items", err)
		return
	}
	defer rows.Close()

	items := make([]Item, 0)
	for rows.Next() {
		var item Item
		if err := rows.Scan(&item.ID, &item.Name, &item.Description, &item.CreatedAt); err != nil {
			respondError(c, http.StatusInternalServerError, "scan item", err)
			return
		}
		items = append(items, item)
	}

	if err := rows.Err(); err != nil {
		respondError(c, http.StatusInternalServerError, "iterate items", err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"items": items})
}

func (a *App) createItem(c *gin.Context) {
	var req createItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		respondError(c, http.StatusBadRequest, "invalid request body", err)
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	var item Item
	err := a.db.QueryRow(
		ctx,
		`INSERT INTO items (name, description) VALUES ($1, $2) RETURNING id, name, description, created_at`,
		req.Name,
		req.Description,
	).Scan(&item.ID, &item.Name, &item.Description, &item.CreatedAt)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "insert item", err)
		return
	}

	_ = a.redis.Del(ctx, cacheKey(item.ID)).Err()
	c.JSON(http.StatusCreated, item)
}

func (a *App) getItem(c *gin.Context) {
	id, err := parseID(c.Param("id"))
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid item id", err)
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	key := cacheKey(id)
	cached, err := a.redis.Get(ctx, key).Result()
	if err == nil {
		var item Item
		jsonErr := json.Unmarshal([]byte(cached), &item)
		if jsonErr == nil {
			a.cacheHits.Add(1)
			c.JSON(http.StatusOK, item)
			return
		}
		log.Printf("cache decode error for key %s: %v", key, jsonErr)
	} else if errors.Is(err, redis.Nil) {
		a.cacheMisses.Add(1)
	} else {
		log.Printf("redis get error for key %s: %v", key, err)
	}

	var item Item
	err = a.db.QueryRow(ctx, `SELECT id, name, description, created_at FROM items WHERE id = $1`, id).
		Scan(&item.ID, &item.Name, &item.Description, &item.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			respondError(c, http.StatusNotFound, "item not found", err)
			return
		}
		respondError(c, http.StatusInternalServerError, "query item", err)
		return
	}

	payload, err := json.Marshal(item)
	if err == nil {
		if setErr := a.redis.Set(ctx, key, payload, a.cacheTTL).Err(); setErr != nil {
			log.Printf("redis set error for key %s: %v", key, setErr)
		}
	}

	c.JSON(http.StatusOK, item)
}

func (a *App) deleteItem(c *gin.Context) {
	id, err := parseID(c.Param("id"))
	if err != nil {
		respondError(c, http.StatusBadRequest, "invalid item id", err)
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	result, err := a.db.Exec(ctx, `DELETE FROM items WHERE id = $1`, id)
	if err != nil {
		respondError(c, http.StatusInternalServerError, "delete item", err)
		return
	}

	if result.RowsAffected() == 0 {
		respondError(c, http.StatusNotFound, "item not found", pgx.ErrNoRows)
		return
	}

	_ = a.redis.Del(ctx, cacheKey(id)).Err()
	c.Status(http.StatusNoContent)
}

func (a *App) cacheStats(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()

	redisHealth := "ok"
	if err := a.redis.Ping(ctx).Err(); err != nil {
		redisHealth = err.Error()
	}

	c.JSON(http.StatusOK, gin.H{
		"cache_hits":   a.cacheHits.Load(),
		"cache_misses": a.cacheMisses.Load(),
		"redis_status": redisHealth,
	})
}

func respondError(c *gin.Context, status int, message string, err error) {
	c.JSON(status, gin.H{
		"error":   message,
		"details": err.Error(),
	})
}

func parseID(raw string) (int64, error) {
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return 0, fmt.Errorf("expected a positive integer")
	}
	return id, nil
}

func cacheKey(id int64) string {
	return fmt.Sprintf("item:%d", id)
}

func getEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func runHealthcheck() int {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://127.0.0.1:8080/health", nil)
	if err != nil {
		log.Printf("healthcheck request error: %v", err)
		return 1
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("healthcheck failed: %v", err)
		return 1
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("healthcheck returned %d", resp.StatusCode)
		return 1
	}

	return 0
}
