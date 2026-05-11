package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
)

type Item struct {
    ID   int    `json:"id"`
    Name string `json:"name"`
}

var items = []Item{{1, "Go Widget"}, {2, "Go Gadget"}}

func main() {
    port := os.Getenv("PORT")
    if port == "" { port = "8080" }

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(map[string]string{"message": "Hello from Go!", "note": "Built with ko - no Dockerfile needed!"})
    })
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
    })
    http.HandleFunc("/items", func(w http.ResponseWriter, r *http.Request) {
        json.NewEncoder(w).Encode(items)
    })

    log.Printf("Starting server on :%s", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
