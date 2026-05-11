import os

from flask import Flask, jsonify

app = Flask(__name__)

ITEMS = [
    {"id": 1, "name": "container basics"},
    {"id": 2, "name": "dev containers"},
    {"id": 3, "name": "codespaces"},
]


@app.get("/")
def home():
    return jsonify({"message": "Welcome to the Flask API for Dev Containers & GitHub Codespaces"})


@app.get("/items")
def items():
    return jsonify({"items": ITEMS})


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
