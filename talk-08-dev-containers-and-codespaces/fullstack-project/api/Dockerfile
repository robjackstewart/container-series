FROM golang:1.22

WORKDIR /workspace/fullstack-project/api

COPY . .

RUN go mod download

EXPOSE 8080

CMD ["go", "run", "main.go"]
