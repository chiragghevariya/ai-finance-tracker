# Project 3: AI-Powered Personal Finance Tracker

**Version:** 1.0
**Stack:** Flutter · Laravel 11 · MySQL · OpenAI API (GPT-4o) · Firebase

---

## Overview

A personal finance tracking application built with Flutter and a Laravel backend. The system allows users to log income and expenses, scan receipts using the device camera, chat with an AI assistant about their spending, and view monthly budget breakdowns with charts. OpenAI GPT-4o powers receipt OCR, auto-categorization, and the natural language finance chat.

---

## System Components

| Component | Technology | Description |
|-----------|-----------|-------------|
| Mobile App | Flutter 3.x | Expense tracking, charts, AI chat, camera scanner |
| Backend API | Laravel 11 | Transaction CRUD, budget logic, OpenAI orchestration |
| Database | MySQL | Users, transactions, categories, budgets |
| AI | OpenAI GPT-4o | Receipt scanning, auto-categorize, finance chat |
| Charts | fl_chart | Pie chart and trend graphs in Flutter |

---

## Database Schema

| Table | Key Columns |
|-------|------------|
| users | id, name, email, password, monthly_budget |
| categories | id, user_id, name, color, icon, is_default |
| transactions | id, user_id, category_id, type (income/expense), amount, description, note, date, receipt_image |
| budgets | id, user_id, category_id, month, year, limit_amount |

---

## Default Categories (Seeded)

| Category | Icon |
|----------|------|
| Food | 🍔 |
| Transport | 🚗 |
| Shopping | 🛍️ |
| Health | 💊 |
| Entertainment | 🎬 |
| Housing | 🏠 |
| Utilities | ⚡ |
| Education | 📚 |
| Travel | ✈️ |
| Other | 💼 |

---

## API Endpoints

### Auth
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | /api/auth/register | No | Register user |
| POST | /api/auth/login | No | Login, returns JWT |
| GET | /api/auth/me | Yes | Authenticated user |

### Transactions
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /api/transactions | Yes | List with type + month filter |
| POST | /api/transactions | Yes | Create transaction |
| PUT | /api/transactions/{id} | Yes | Update transaction |
| DELETE | /api/transactions/{id} | Yes | Delete transaction |
| GET | /api/transactions/summary?month=&year= | Yes | Monthly summary by category |

### Categories & Budgets
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /api/categories | Yes | User's categories |
| POST | /api/budgets | Yes | Set monthly budget for category |
| GET | /api/budgets?month=&year= | Yes | Budget vs actual for month |

### AI Endpoints
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | /api/receipt/scan | Yes | Extract data from receipt image via GPT-4o |
| POST | /api/ai/chat | Yes | Natural language finance question |
| POST | /api/transactions/auto-categorize | Yes | Suggest category from description |

---

## Build Phases

### Phase 1 — Laravel Backend: Setup, Auth & Transactions API

```
I am building an AI-powered personal finance tracker backend using Laravel 11.
This is Phase 1: Project setup and transactions API.

Please create the following step by step:

1. Laravel 11 project with packages:
   - tymon/jwt-auth
   - openai-php/laravel

2. Database migrations:
   - users (id, name, email, password, monthly_budget)
   - categories (id, user_id, name, color, icon, is_default)
   - transactions (id, user_id, category_id, type [income/expense], amount,
     description, note, date, receipt_image)
   - budgets (id, user_id, category_id, month, year, limit_amount)

3. CategorySeeder — 10 default categories with color hex and emoji icon:
   Food #FF6B6B 🍔, Transport #4ECDC4 🚗, Shopping #45B7D1 🛍️,
   Health #96CEB4 💊, Entertainment #FFEAA7 🎬, Housing #DDA0DD 🏠,
   Utilities #F0E68C ⚡, Education #98D8C8 📚, Travel #FFB347 ✈️, Other #C0C0C0 💼

4. API endpoints:
   - POST /api/auth/register
   - POST /api/auth/login
   - GET  /api/auth/me
   - GET/POST/PUT/DELETE /api/transactions
   - GET /api/transactions/summary?month=&year=
       Returns: total_income, total_expense, balance, breakdown by category
   - GET /api/categories
   - POST /api/budgets
   - GET  /api/budgets?month=&year=

5. TransactionController with full working code.
6. SummaryService class to calculate monthly totals and per-category breakdown.

Add clear comments on every important line.
```

---

### Phase 2 — Laravel Backend: OpenAI Integration

```
This is Phase 2 of the AI finance tracker Laravel backend.
Phase 1 is complete: auth and transactions API are working.

Now add the three AI-powered endpoints using openai-php/laravel:

1. Receipt OCR — POST /api/receipt/scan:
   - Accept base64 image or file upload
   - Send to OpenAI GPT-4o Vision API with this prompt:
     "Extract the following from this receipt image and return JSON only,
      no extra text: { total_amount, merchant_name, date, category }.
      For category, pick the closest match from:
      Food, Transport, Shopping, Health, Entertainment, Housing,
      Utilities, Education, Travel, Other."
   - Parse the JSON response
   - Return parsed fields to the app

2. Finance Chat — POST /api/ai/chat:
   - Accept: { message: "string" }
   - Fetch authenticated user's last 90 days of transactions from DB
   - Build a plain-text summary:
       "User has X transactions. Total income: $Y. Total expenses: $Z.
        Top categories: Food $A, Transport $B, Shopping $C."
   - Call OpenAI Chat API with:
       System: "You are a personal finance assistant. Answer only based
                on the transaction data provided. Be concise."
       User: [the summary + the user's message]
   - Return the AI text response

3. Auto-Categorize — POST /api/transactions/auto-categorize:
   - Accept: { description: "string" }
   - Fetch user's category list from DB
   - Ask OpenAI: "Given this transaction description: '{description}',
     which category fits best from this list: {categories}?
     Return only the category name, nothing else."
   - Match response to a category record and return { category_id, category_name }

4. Create ReceiptController and AIController with full working code.
5. Add OPENAI_API_KEY to .env.example.

Add clear comments on every line.
```

---

### Phase 3 — Flutter App: Transactions, Charts & Camera

```
This is Phase 3 — the Flutter app for the AI finance tracker.
The Laravel backend from Phases 1 and 2 is complete.

Stack: Flutter 3.x, Provider, Dio, fl_chart, image_picker.

Create the full project with these files and screens:

1. Setup:
   - pubspec.yaml dependencies: dio, provider, fl_chart, image_picker,
     intl, shared_preferences, cached_network_image
   - lib/config/api_config.dart: base URL constant
   - lib/services/api_service.dart: Dio instance with JWT Authorization interceptor
   - lib/providers/auth_provider.dart: login, logout, user state
   - lib/providers/transaction_provider.dart: fetch, create, delete transactions

2. Screens:
   - SplashScreen → check token → LoginScreen or HomeScreen
   - LoginScreen: email + password, validation
   - RegisterScreen: name, email, password, monthly budget input

   - HomeScreen with bottom navigation (4 tabs):

       Tab 1 — Dashboard:
         Monthly balance card showing income - expenses
         PieChart (fl_chart) of spending by category
         List of 5 most recent transactions

       Tab 2 — Transactions:
         FlatList of all transactions
         Filter row: All / Income / Expense buttons + month picker
         FAB to open AddTransactionSheet

       Tab 3 — AI Chat:
         (Implemented in Phase 4)

       Tab 4 — Profile:
         Display user name and email
         Monthly budget input field with Save button

3. AddTransactionSheet (bottom sheet):
   - Amount field (number keyboard)
   - Description text field
   - Date picker
   - Category dropdown populated from API
   - Type toggle: Income / Expense
   - Camera icon button (Phase 4 connects this to receipt scanner)
   - Save button: POST /api/transactions

4. TransactionCard widget:
   - Category icon and color
   - Description and date
   - Amount in green (income) or red (expense)

5. PieChart using fl_chart showing category breakdown from summary API.

UI: white background, green #2E7D32 for income, red #C62828 for expenses.
Add clear comments on every widget and function.
```

---

### Phase 4 — Flutter: AI Chat & Receipt Scanner

```
This is Phase 4 — AI features for the Flutter finance tracker.
Phase 3 Flutter app is complete.

Now implement two AI-powered features:

1. AI Chat Screen (Tab 3 in HomeScreen):
   - Chat UI: user messages right-aligned, AI messages left-aligned
   - Text input field at the bottom with send button
   - On send: POST /api/ai/chat with the message
   - Show a loading indicator while waiting for response
   - Display AI response as a new message bubble

   Suggestion chips above the input (pre-fill the text field when tapped):
     "Where did I spend most this month?"
     "Am I over budget?"
     "What are my top 3 expense categories?"
     "How much did I spend on food?"

   Chat history stored in a List<Map> in the widget state (not persisted).

2. Receipt Scanner in AddTransactionSheet:
   - Camera icon button below the description field
   - On tap: open image_picker (camera or gallery)
   - Display selected image as a small preview in the form
   - "Scan with AI" button: POST /api/receipt/scan with base64 image
   - Show loading text: "Extracting receipt data..."
   - On response: auto-fill amount, description, and select category
   - User can review all fields before tapping Save

3. Auto-Categorize in AddTransactionSheet:
   - After user stops typing in the description field (1 second debounce)
   - POST /api/transactions/auto-categorize with the description
   - Auto-select the returned category in the dropdown
   - Show a small label "Suggested" next to the category dropdown

4. Add error handling for all three AI features:
   - Show a snackbar with the error message if any request fails
   - Keep previously entered data intact on failure

Add clear comments on every function and widget.
```

---

### Phase 5 — Seed Data & Documentation

```
This is Phase 5 — seed data and documentation for the AI finance tracker.
All code from Phases 1–4 is complete.

1. Laravel Seeder:
   - 1 demo user: demo@finance.com / password123
   - Monthly budget: $3000
   - 3 months of transaction data (approximately 35 transactions per month):
       Income: 1 salary entry per month ($5000)
       Expenses: realistic mix across all 10 categories
       Vary amounts naturally (e.g. Food $8–$65, Transport $15–$120)
   - Budget limits set for 5 categories for the current month

2. README.md for the GitHub repository:
   - Project title and description
   - Screenshots placeholder section
   - Feature list
   - Tech stack table (Flutter, Laravel, OpenAI, MySQL)
   - Setup instructions: backend and Flutter app
   - .env configuration guide (highlight OPENAI_API_KEY requirement)
   - Demo credentials table
   - API endpoint reference table

3. 60-second screen recording script:
   - List each screen and action in order
   - Flow: login → dashboard with chart → add transaction manually →
     open receipt scanner → scan receipt → fields auto-fill →
     open AI chat tab → type question → show AI response
```

---

## Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Demo User | demo@finance.com | password123 |

---

## Environment Variables

```env
APP_NAME=FinanceTracker
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_DATABASE=finance_tracker
DB_USERNAME=root
DB_PASSWORD=

JWT_SECRET=
JWT_TTL=60

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o
```
