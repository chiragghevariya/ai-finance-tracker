# 💰 AI-Powered Personal Finance Tracker

> A cross-platform personal finance app that turns everyday spending into clear, AI-driven insights — built with **Flutter + Laravel + OpenAI (GPT-4o)**.

Snap a receipt and let AI fill in the details, chat with your finances in plain English, and watch smart budgets flag overspending before it adds up.

---

## ✨ Features

- 🤖 **AI Finance Chat** — ask natural-language questions like *"Where did I spend most last month?"* and get answers grounded in your real transaction history.
- 📸 **Receipt Scanning** — photograph a receipt and **GPT-4o Vision** extracts the merchant, amount, date, and category, auto-filling the form.
- 🧠 **Smart Auto-Categorization** — descriptions are categorized automatically as you type (debounced AI suggestion).
- 📊 **Dashboard & Charts** — monthly balance, income vs. expense, and a spending-by-category pie chart (`fl_chart`).
- 💸 **Transactions** — full CRUD with type/month filters, swipe-to-delete, and pull-to-refresh.
- 🎯 **Budgets** — per-category monthly limits with live "spent vs. remaining" tracking.
- 🔐 **JWT Auth** — register/login/logout with token-based authentication.
- 🗂️ **10 default categories** with colors + emoji icons, plus per-user custom categories.

---

## 🛠️ Tech Stack

| Layer        | Technology |
|--------------|------------|
| **Mobile**   | Flutter 3.x · Dart 3 · Provider · Dio · fl_chart · image_picker · intl |
| **Backend**  | Laravel 11 · PHP 8.3 · JWT (`tymon/jwt-auth`) |
| **AI**       | OpenAI **GPT-4o** via `openai-php/laravel` (Vision + Chat) |
| **Database** | SQLite (default, zero-config) · MySQL-compatible |
| **Auth**     | JSON Web Tokens (Bearer) |

---

## 📸 Screenshots

> _Add your screenshots to `docs/screenshots/` and they'll render here._

| Dashboard | AI Chat | Receipt Scan | Add Transaction |
|-----------|---------|--------------|-----------------|
| ![Dashboard](docs/screenshots/dashboard.png) | ![AI Chat](docs/screenshots/chat.png) | ![Receipt](docs/screenshots/receipt.png) | ![Add](docs/screenshots/add.png) |

---

## 🚀 Getting Started

### 1. Backend (Laravel API)

```bash
# From the project root
composer install
cp .env.example .env
php artisan key:generate
php artisan jwt:secret            # generates the JWT signing key

# SQLite (default) — create the database file, then migrate + seed demo data
touch database/database.sqlite
php artisan migrate:fresh --seed

php artisan serve                 # http://127.0.0.1:8000
```

### 2. Frontend (Flutter app)

```bash
cd flutter_app
flutter create --platforms=android,ios,web .   # adds platform folders, keeps lib/
flutter pub get
flutter run
```

Set the API host in `flutter_app/lib/config/api_config.dart`:

| Running on        | `baseUrl`                          |
|-------------------|------------------------------------|
| Android emulator  | `http://10.0.2.2:8000/api` (default) |
| iOS simulator     | `http://127.0.0.1:8000/api`        |
| Real device       | `http://<your-PC-LAN-IP>:8000/api` |

> **Android note:** add `android:usesCleartextTraffic="true"` to the `<application>` tag in `android/app/src/main/AndroidManifest.xml` so the emulator can reach a local `http://` server. See `flutter_app/README.md` for camera/photo permission setup.

---

## 🔑 Environment — OpenAI API Key

The AI features (chat, receipt scan, auto-categorize) call OpenAI. Add your key to `.env`:

```env
OPENAI_API_KEY=sk-your-key-here
OPENAI_ORGANIZATION=
OPENAI_REQUEST_TIMEOUT=30
```

Get a key at <https://platform.openai.com/api-keys>. After editing `.env`, run `php artisan config:clear`.

> The app **runs fine without a key** — the AI endpoints simply return a friendly *"OpenAI API key is not configured"* message instead of crashing, so the rest of the app stays fully usable.

---

## 👤 Demo Login

The seeder creates a demo account with ~3 months of realistic spending:

```
Email:    demo@finance.com
Password: password123
```

---

## 📡 API Endpoints

Base URL: `/api` · 🔒 = requires `Authorization: Bearer <token>`

| Method | Endpoint | Auth | Description |
|--------|----------|:----:|-------------|
| `POST` | `/register` | — | Create an account, returns a JWT |
| `POST` | `/login` | — | Log in, returns a JWT |
| `GET`  | `/me` | 🔒 | The current user |
| `POST` | `/logout` | 🔒 | Invalidate the token |
| `GET`  | `/transactions` | 🔒 | List (filters: `type`, `month`, `year`; paginated) |
| `POST` | `/transactions` | 🔒 | Create a transaction |
| `GET`  | `/transactions/{id}` | 🔒 | Show one transaction |
| `PUT`  | `/transactions/{id}` | 🔒 | Update a transaction |
| `DELETE` | `/transactions/{id}` | 🔒 | Delete a transaction |
| `GET`  | `/transactions/summary?month=&year=` | 🔒 | Totals + spending by category |
| `POST` | `/transactions/auto-categorize` | 🔒 | 🤖 AI category suggestion |
| `GET`  | `/categories` | 🔒 | Default + user categories |
| `GET`  | `/budgets?month=&year=` | 🔒 | Budgets with spent/remaining |
| `POST` | `/budgets` | 🔒 | Create or update a budget |
| `POST` | `/receipt/scan` | 🔒 | 🤖 Receipt OCR (GPT-4o Vision) |
| `POST` | `/ai/chat` | 🔒 | 🤖 Chat with your finances |

---

## 📂 Project Structure

```
ai-finance-tracker/
├── app/                  # Laravel API (Controllers, Models, Services)
│   ├── Http/Controllers/Api/   # Auth, Transaction, Category, Budget, Receipt, AI
│   └── Services/               # SummaryService, OpenAiService
├── database/             # migrations + seeders (CategorySeeder, DemoSeeder)
├── routes/api.php        # all API routes
└── flutter_app/          # Flutter mobile app
    └── lib/              # config, models, services, providers, screens, widgets
```

---

## 📝 License

MIT — free to use for learning and portfolios.
