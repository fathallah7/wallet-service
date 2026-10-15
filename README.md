<p align="center">
  <h1 align="center">Wallet Service API</h1>
  <p align="center">A digital wallet backend API built with Go</p>
</p>

<p align="center">
  <a href="https://go.dev/"><img src="https://img.shields.io/badge/Go-1.25+-00ADD8?style=flat&logo=go" alt="Go version"></a>
  <a href="https://github.com/golang-migrate/migrate"><img src="https://img.shields.io/badge/migrations-golang--migrate-blue" alt="Migrations"></a>
  <a href="https://www.postgresql.org/"><img src="https://img.shields.io/badge/database-PostgreSQL-4169E1?style=flat&logo=postgresql" alt="PostgreSQL"></a>
  <a href="https://jwt.io/"><img src="https://img.shields.io/badge/auth-JWT-000000?style=flat&logo=jsonwebtokens" alt="JWT"></a>
</p>

---

## Overview

**Wallet Service API** is a RESTful backend for a digital wallet platform. Users can register, create wallets (max 3 per user), deposit funds, and transfer money between wallets — all secured with JWT authentication and protected against race conditions with database-level row locking.


---

## Features

- **User Management** — Register, login, JWT-based authentication
- **Multi-Wallet Support** — Up to 3 wallets per user with default wallet selection
- **Transfers** — Secure peer-to-peer transfers between wallets
- **Deposits** — Add funds to any wallet
- **Transaction History** — Full audit trail of all transactions
- **Race Condition Protection** — Row-level `FOR UPDATE` locking + database transactions
- **Idempotent Validation** — Wallet limits enforced at both application and database levels
- **Precision Money Handling** — All financial values use `decimal.Decimal` to avoid floating-point errors
- **Stripe Payment Gateway** — Deposit funds via Stripe Checkout Sessions with webhook confirmation

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│   Handler   │────▶│   Service    │────▶│    Store     │────▶│  PostgreSQL │
│  (HTTP)     │     │  (Business)  │     │   (Data)     │     │             │
└─────────────┘     └──────────────┘     └──────────────┘     └─────────────┘
       │                    │                      │
       │                    │                      │
   JSON I/O            Validation                SQL Queries
   Status Codes        Orchestration             Database Tx
   Error Mapping       Error Types               Row Locking
```

### Layered Design

| Layer       | Responsibility                                                             |
| ----------- | -------------------------------------------------------------------------- |
| **Handler** | HTTP request/response, JSON serialization, body size limits, error mapping |
| **Service** | Business logic, validation, orchestration of stores                        |
| **Store**   | Raw SQL queries, database transactions, row locking                        |
| **Model**   | Domain entities (User, Wallet, Transaction)                                |
| **DTO**     | Request/response data transfer objects                                     |

---

## Tech Stack

| Technology                                                  | Purpose                                                     |
| ----------------------------------------------------------- | ----------------------------------------------------------- |
| [Go](https://go.dev/) 1.22+                                 | Programming language with enhanced `net/http` ServeMux      |
| [PostgreSQL](https://www.postgresql.org/)                   | Relational database                                         |
| [lib/pq](https://github.com/lib/pq)                         | PostgreSQL driver                                           |
| [golang-jwt/jwt/v5](https://github.com/golang-jwt/jwt)      | JWT token generation and validation                         |
| [golang-migrate](https://github.com/golang-migrate/migrate) | Database migrations                                         |
| [shopspring/decimal](https://github.com/shopspring/decimal) | Arbitrary-precision decimal arithmetic for financial values |
| [bcrypt](https://pkg.go.dev/golang.org/x/crypto/bcrypt)     | Password hashing                                            |
| [godotenv](https://github.com/joho/godotenv)                | Environment variable loading                                |
| [Stripe Go SDK](https://github.com/stripe/stripe-go)       | Payment processing via Stripe Checkout + Webhooks           |

---

## API Reference

### Health

```
GET /health
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "service is healthy",
  "data": { "status": "running" }
}
```

---

### Authentication

#### Register

```
POST /auth/register
```

Request body:

```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "phone": "+1234567890",
  "password": "securepass123"
}
```

Response: `201 Created`

```json
{
  "success": true,
  "message": "account created successfully",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "phone": "+1234567890"
    }
  }
}
```

#### Login

```
POST /auth/login
```

Request body:

```json
{
  "email": "john@example.com",
  "password": "securepass123"
}
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "login successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "phone": "+1234567890"
    }
  }
}
```

---

### Wallets

> All wallet endpoints require `Authorization: Bearer <token>` header.

#### Create Wallet

```
POST /wallet
```

Request body:

```json
{
  "name": "Savings"
}
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "wallet created successfully",
  "data": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Savings",
    "balance": 0,
    "is_default": false,
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

#### List Wallets

```
GET /wallets
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "wallets retrieved successfully",
  "data": [
    {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Savings",
      "balance": 1000.5,
      "is_default": true,
      "created_at": "2025-01-01T00:00:00Z"
    }
  ]
}
```

#### Get Wallet by ID

```
GET /wallet/{wallet_id}
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "wallet retrieved successfully",
  "data": {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Savings",
    "balance": 1000.5,
    "is_default": false,
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

#### Set Default Wallet

```
PUT /wallet/{wallet_id}/default
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "default wallet set successfully",
  "data": null
}
```

---

### Transactions

> All transaction endpoints require `Authorization: Bearer <token>` header.

#### Transfer

```
POST /transactions/transfer
```

Request body:

```json
{
  "from_wallet_id": "660e8400-e29b-41d4-a716-446655440001",
  "to_wallet_id": "660e8400-e29b-41d4-a716-446655440002",
  "amount": 250.0
}
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "transfer successful",
  "data": null
}
```

#### Deposit

Initiates a deposit by creating a Stripe Checkout Session. The user is redirected to the returned `checkout_url` to complete payment via Stripe.

```
POST /transactions/deposit
```

Request body:

```json
{
  "wallet_id": "660e8400-e29b-41d4-a716-446655440001",
  "amount": 500.0
}
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "deposit successful",
  "data": {
    "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_..."
  }
}
```

#### Get Transactions

```
GET /transactions
```

Response: `200 OK`

```json
{
  "success": true,
  "message": "transactions retrieved successfully",
  "data": [
    {
      "id": "770e8400-e29b-41d4-a716-446655440003",
      "from_wallet_id": "660e8400-e29b-41d4-a716-446655440001",
      "to_wallet_id": "660e8400-e29b-41d4-a716-446655440002",
      "amount": 250.0,
      "type": "transfer",
      "status": "completed",
      "created_at": "2025-01-01T12:00:00Z"
    }
  ]
}
```

---

### Payments

#### Stripe Webhook

> Public endpoint — Stripe posts here after payment events. No auth required.

```
POST /webhook/stripe
```

Stripe sends events (e.g. `checkout.session.completed`) to this endpoint. On successful payment, the wallet balance is updated and a deposit transaction record is created.

Response: `200 OK`

---

## Getting Started

### Prerequisites

- [Go](https://go.dev/dl/) 1.22 or higher
- [PostgreSQL](https://www.postgresql.org/download/) 14 or higher
- [golang-migrate](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate) (optional, for running migrations)
- [Make](https://www.gnu.org/software/make/) (optional, for using Makefile commands)

### 1. Clone the repository

```bash
git clone https://github.com/fathallah7/digital-wallet-backend.git
cd digital-wallet-backend
```

### 2. Create the database

```bash
createdb digital_wallet
```

### 3. Configure environment

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

```env
PORT=:8080
DB_DSN=postgres://postgres:yourpassword@localhost:5432/wallet_service?sslmode=disable
JWT_SECRET=your-256-bit-secret-here
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

> **Security tip**: Generate a strong JWT secret with `openssl rand -base64 32`. Stripe keys are read directly from environment variables.

### 4. Run migrations

```bash
make migrateup
```

Or manually using golang-migrate:

```bash
migrate -path db/migrations -database "$DB_DSN" up
```

### 5. Start the server

```bash
make run
```

```bash
go run cmd/api/main.go
```

The server will start on `http://localhost:8080`.

---

## Project Structure

```
digital-wallet-backend/
├── cmd/
│   └── api/
│       └── main.go              # Entry point
├── db/
│   └── migrations/              # SQL migrations (up/down)
├── internal/
│   ├── apperrors/               # Custom error types
│   ├── config/                  # Environment config loader
│   ├── database/                # Database connection & pool config
│   ├── dto/                     # Request/response data transfer objects
│   ├── handler/                 # HTTP handlers + response helpers
│   ├── middleware/              # JWT authentication middleware
│   ├── model/                   # Domain models (User, Wallet, Transaction)
│   ├── router/                  # Route registration
│   ├── service/                 # Business logic layer
│   └── store/                   # Data access layer (SQL queries)
├── .env.example                 # Environment template
├── go.mod / go.sum              # Go module files
├── Makefile                     # Build & migration commands
└── README.md
```

---

## Database Schema

<details>
<summary>Click to expand</summary>

### Users

```sql
CREATE TABLE users (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name  VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,
    phone      VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255),
    google_id  VARCHAR(255),
    email_verified_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Wallets

```sql
CREATE TABLE wallets (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       VARCHAR(100) NOT NULL DEFAULT 'My Wallet',
    balance    NUMERIC(19,4) NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

- Enforced trigger: maximum 3 wallets per user
- Indexed on `user_id`

### Transactions

```sql
CREATE TABLE transactions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_wallet_id UUID REFERENCES wallets(id),
    to_wallet_id   UUID REFERENCES wallets(id),
    amount         NUMERIC(19,4) NOT NULL,
    type           VARCHAR(50) NOT NULL,
    status         VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);
```

- Indexed on both `from_wallet_id` and `to_wallet_id`

</details>

---

## Security

- **Password Hashing** — bcrypt with default cost
- **JWT Authentication** — HS256 signed tokens with 24h expiry
- **Row-Level Locking** — `SELECT ... FOR UPDATE` prevents race conditions during transfers
- **Request Size Limits** — 1 MB max request body
- **Input Validation** — All inputs validated before processing
- **Sensitive Field Protection** — `password_hash` excluded from JSON responses

---

## Makefile Commands

| Command                   | Description                |
| ------------------------- | -------------------------- |
| `make run`                | Start the API server       |
| `make migrateup`          | Run all pending migrations |
| `make migratedown`        | Rollback all migrations    |
| `make migration name=xxx` | Create a new migration     |
| `make install-tools`      | Install migration CLI tool |
