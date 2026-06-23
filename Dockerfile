# ======================
# Build stage
# ======================
FROM golang:1.26.4-alpine3.23 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build API binary
RUN CGO_ENABLED=0 GOOS=linux go build -o wallet-service ./cmd/api

# Install migrate binary
RUN go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest


# ======================
# Runtime stage
# ======================
FROM alpine:latest

WORKDIR /app

# certificates are useful for https calls
RUN apk add --no-cache ca-certificates

# API binary
COPY --from=builder /app/wallet-service .

# Migrate binary
COPY --from=builder /go/bin/migrate /usr/local/bin/migrate

# migrations files
COPY --from=builder /app/db ./db

# env file (optional)
COPY .env.docker .

EXPOSE 8080

CMD ["./wallet-service"]
