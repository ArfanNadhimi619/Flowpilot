# Enterprise Automation Suite

A responsive React + Tailwind operations dashboard with a FastAPI AI service and Supabase/Postgres schema.

## Stack
- Frontend: React, Vite, TypeScript, Tailwind CSS, Recharts, Lucide icons
- Backend: Python 3.11+, FastAPI, Supabase Python client, OpenAI Python SDK
- Database/auth: Supabase Postgres + Auth + Row Level Security

## Included modules
- Overview dashboard and business analytics
- Inventory and supplier management
- Customer and order management
- Shipment/logistics tracking
- AI agent control centre
- AI assistant chat interface
- Reusable UI components and responsive navigation

## Quick start

### 1. Configure Supabase
1. Create a Supabase project.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Copy the Project URL and anon key from Project Settings → API.

### 2. Configure the API
```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```
Set `OPENAI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `OPENAI_MODEL` in `backend/.env`.
Never expose the service-role key or AI provider key to the browser.
For local testing without Supabase, set `LOCAL_DEMO_MODE=true` in `backend/.env`. This enables loopback-only SQLite storage at `backend/data/flowpilot-demo.sqlite3`; it is local demo data, not your Supabase project. Keep it `false` when using Supabase or deploying the API.

Start the API:
```bash
uvicorn app.main:app --reload --port 8000
```
API docs: http://localhost:8000/docs

### 3. Configure the frontend
```bash
cd frontend
npm install
cp .env.example .env
npm run dev
```
Set `VITE_API_URL=http://localhost:8000` and `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`.
Open the Vite URL shown in the terminal.
In Settings, sign in with an existing Supabase Auth user. The user must have an `organization_members` row with an owner, admin, operator, or viewer role. Product creation requires owner, admin, or operator access.

## AI assistant
The chat UI calls `POST /api/chat` with the signed-in user's access token. The backend verifies the token, derives the organization from membership, and loads all active products for the model's inventory context. Configure a valid `OPENAI_API_KEY` and `OPENAI_MODEL` in `backend/.env` for generated answers. Without an OpenAI key, built-in inventory prompts return clearly labeled sample-data or live-inventory summaries in the UI.

## Data access
The frontend authenticates with Supabase Auth and uses the anon key. `GET /api/products` reads the signed-in user's active organization inventory; `POST /api/products` saves the SKU, name, unit price, and quantity to that organization. The FastAPI service uses the service-role key only on the server, validates bearer tokens through Supabase Auth, and derives tenant scope and write permissions from membership. The browser only updates its product list after the API confirms the database insert.

## Production checklist
- Add organization onboarding and invite flows.
- Verify Supabase JWTs on every protected API route and derive `org_id` from membership, never from an untrusted request body.
- Store provider credentials in a secrets manager or KMS-backed vault. `ai_agent_keys` stores a secret reference, not plaintext API keys.
- Add audit logs, rate limits, request tracing, idempotency keys, and background jobs for long-running workflows.
- Configure CORS to exact production origins, HTTPS, backups, monitoring, and database migration review.
- Add tests for authorization, tenant isolation, prompt injection, and business actions.
