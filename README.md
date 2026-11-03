# Findu API

<div align="center">

[![Ruby](https://img.shields.io/badge/Ruby-3.3.5-CC342D?style=for-the-badge&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-7.0_API-D30001?style=for-the-badge&logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io/)
[![Sidekiq](https://img.shields.io/badge/Sidekiq-7-B51817?style=for-the-badge&logo=sidekiq&logoColor=white)](https://sidekiq.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Architecture](https://img.shields.io/badge/Architecture-DDD-2E7D32?style=for-the-badge)](https://en.wikipedia.org/wiki/Domain-driven_design)

**Intelligent, multi-modal personal financial copilot backend API.**  
*Transforms unstructured raw inputs—voice notes, receipts, WhatsApp chats, and messages—into verified, deterministic financial entries, real-time analytics, and proactive wealth planning.*

[Key Features](#-key-features) • [Architecture](#-architecture) • [Tech Stack](#-tech-stack) • [Quick Start](#-quick-start) • [API Overview](#-api-overview) • [Documentation](#-documentation)

---

</div>

## 💡 Overview

**FindU** is a personal finance backend built with **Ruby on Rails 7 (API-only)** following **Domain-Driven Design (DDD)**. 

Traditional budgeting apps require tedious manual input. FindU solves this by ingesting raw, unstructured inputs (WhatsApp text messages, audio voice notes, photo receipts, or chat dialogues) and leveraging **Google Gemini** with structured output schemas to classify intents and extract transactions. Financial rules, account balances, and business logic remain strictly deterministic and auditable within clean domain use cases.

---

## ✨ Key Features

- 🎙️ **Multi-Modal Ingestion Pipeline**
  - **WhatsApp & Messaging**: Inbound webhooks (Twilio) to capture expenses and commands straight from messaging platforms.
  - **Receipt & Invoice OCR**: Upload receipts as artifacts; extracts vendor, line items, and totals asynchronously via background workers.
  - **Audio Transcription**: Process voice notes into structured text entries automatically.
- 🧠 **AI & LLM Orchestration**
  - Schema-enforced extraction powered by `RubyLLM` and Google Gemini.
  - Dynamic financial insights, spending analysis, and proactive tips.
  - Multi-agent conversational assistant with context preservation.
- 📊 **Comprehensive Financial Engine**
  - **Statements & Accounting**: Income/expense tracking with monthly competency periods (`competency_month`), paid/pending status, and tags.
  - **Installment Plans & Recurrence**: Native support for split installments (*parcelamentos*) and recurring automated obligations.
  - **Budgets & Spending Caps**: Category-level budgets with live burn-rate and threshold indicators.
  - **Goals & Envelopes ("Boxes")**: Goal contribution milestones and customizable virtual sub-accounts (*caixinhas*) with movement audit trails.
  - **Receipt Management**: Auto-generate, deliver, and download formal receipts.
- ⚡ **Real-Time & Asynchronous Processing**
  - **Sidekiq 7**: Offloads OCR parsing, AI classifications, push notifications, and webhook handling.
  - **Action Cable**: WebSocket streaming for live chat responses and real-time user notification feeds.
- 🔒 **Security & Multi-Tenant Isolation**
  - Stateless **Devise-JWT** authentication with JTI revocation blocklists and token refreshes.
  - Strict user-scoped isolation across all controllers and domain queries (`current_user`).

---

## 🏛️ Architecture

FindU follows a strict **Domain-Driven Design (DDD)** pattern that decouples business rules from the HTTP transport and third-party infrastructure.

```
app/
├── controllers/          # HTTP boundary (api/v1/*), param filtering, status codes
├── domain/               # Pure business domain
│   ├── support/          # Value objects, validators, and domain helpers
│   └── use_case/         # Action orchestrators (e.g., Financial::Statement::*, Chat::*)
├── models/               # Active Record persistence entities (UUID primary keys)
├── infrastructure/       # External gateways (Gemini LLM, OCR, Twilio, FCM Push, Formatters)
├── serializers/          # Fast, deterministic JSON serialization via Blueprinter
├── channels/             # Action Cable WebSockets (Chat streaming, Notifications)
└── jobs/                 # Sidekiq background workers
```

---

## 🛠️ Tech Stack

| Category | Technology | Purpose |
|---|---|---|
| **Core Framework** | **Ruby 3.3.5** / **Rails 7.0** | High-productivity API-only backend |
| **Primary Database** | **PostgreSQL 16** | Relational store with UUID primary keys & JSONB |
| **Cache & Queue** | **Redis 7** + **Sidekiq 7** | High-performance asynchronous background processing |
| **AI / LLM Engine** | **Google Gemini** via `RubyLLM` | Intent classification, schema-enforced entity extraction, OCR |
| **Authentication** | **Devise** + **Devise-JWT** | Token-based auth with JTI revocation strategy & refresh tokens |
| **Serialization** | **Blueprinter** | Declarative, lightweight, high-speed JSON serializers |
| **Real-time** | **Action Cable** | WebSockets for token-by-token chat streaming |
| **Push & Messaging** | **Twilio** & **Firebase Cloud Messaging** | WhatsApp webhooks & native mobile push notifications |
| **Storage** | **Active Storage** (Supabase S3) | Encrypted storage for receipts, invoices, and voice audio files |
| **Testing** | **RSpec**, **FactoryBot**, **Faker** | Unit, integration, and request test coverage |

---

## 🚀 Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- *(Alternative for bare-metal)*: Ruby 3.3.5, PostgreSQL 16, and Redis 7

### 1. Clone & Configure Environment

```bash
git clone https://github.com/your-username/findu.git
cd findu

# Copy environment variables template
cp .env.example .env
```

Edit `.env` and fill in your credentials (at minimum `GEMINI_API_KEY` for AI features).

---

### 2. Run with Docker Compose (Recommended)

Docker Compose starts the Rails API, PostgreSQL, Redis, Sidekiq, and Maildev:

```bash
# Build and run the services
docker compose up --build
```

- **API Server**: Accessible at `http://localhost:3000`
- **Maildev UI**: Accessible at `http://localhost:1080` (intercepts outgoing development emails)
- **Sidekiq Worker**: Automatically boots and watches background queues

---

### 3. Alternative: Run Locally (Bare-Metal)

```bash
# Install Ruby dependencies
bundle install

# Setup database (create, migrate, and seed)
bin/rails db:prepare

# Start the Rails server
bin/rails server -p 3000

# In a separate terminal, start Sidekiq
bundle exec sidekiq
```

---

## 🔑 Environment Variables

Key variables defined in `.env.example`:

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis server URL for cache and Sidekiq |
| `GEMINI_API_KEY` | Google Gemini API key for LLM queries & vision OCR |
| `GEMINI_MODEL_CHAIN` | LLM model alias (default: `gemini-2.5-flash`) |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` | Twilio credentials for WhatsApp integration |
| `FCM_SERVICE_ACCOUNT_JSON` | Firebase service account credentials for push notifications |
| `SUPABASE_*` | Supabase S3 credentials for Active Storage |
| `FRONTEND_ORIGIN` | Allowed CORS origins for web and mobile frontends |

---

## 📡 API Overview

All API endpoints are versioned under `/api/v1`. Protected endpoints require a Bearer token:

```http
Authorization: Bearer <your_jwt_token>
```

### Core Route Namespaces

| Namespace | Base Path | Description |
|---|---|---|
| **Health** | `GET /health` | Health check endpoint |
| **Auth** | `/api/v1/login`, `/api/v1/logout` | Session creation and token revocation |
| **Token** | `POST /api/v1/token/refresh` | Refresh expired JWT token |
| **User Profile** | `/api/v1/user` | Account registration, profile fetch, and updates |
| **Financial** | `/api/v1/financial/*` | Statements, entries, categories, budgets, goals, boxes |
| **Artifacts** | `/api/v1/artifacts` | Receipt uploads, async OCR extraction results |
| **Chat & AI** | `/api/v1/chat/*` | Conversations, messages, agent definitions, streaming |
| **Intelligence** | `/api/v1/intelligence/insights` | Smart financial insights & anomaly detection |
| **Inbound** | `/api/v1/inbound/messages` | Webhook ingress for WhatsApp / Twilio messages |
| **Notifications** | `/api/v1/notifications` | Feed, unread counts, preferences, and device registration |

> 📖 **Complete Documentation**: For exhaustive request/response schemas, query parameters, and error codes, refer to [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) and [`docs/API.md`](docs/API.md).

---

## 🧪 Testing & Code Quality

The test suite is powered by **RSpec**:

```bash
# Run all specs
bundle exec rspec

# Run specific domain or request specs
bundle exec rspec spec/domain/
bundle exec rspec spec/requests/
```

---

## 📚 Documentation

Detailed technical documentation is available in the [`docs/`](docs/) directory:

- 📋 [**API Contract**](docs/API_CONTRACT.md): Comprehensive endpoint-by-endpoint schema contract.
- 💬 [**Action Cable Specs**](docs/ACTION_CABLE.md): WebSocket channels for chat streaming & notification feeds.
- 🚀 [**Deployment Guide**](docs/DEPLOY.md): Fly.io and production container deployment instructions.
- ☁️ [**AWS Migration**](docs/AWS-MIGRATION.md): Architecture specifications for AWS infrastructure.
- 🔄 [**CI/CD Pipeline**](docs/CICD.md): GitHub Actions automation workflows.

---

## 📄 License

This project is licensed under the terms described in the repository.
