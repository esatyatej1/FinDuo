# 💳 FinDuo — Enterprise-Grade Personal & Couples Finance Platform

FinDuo is a modern, high-performance financial tracking and analytics platform designed specifically for couples and personal wealth management. The system is split into an elegant Flutter-based cross-platform client application and a robust, async FastAPI backend built on PostgreSQL, featuring an integrated AI financial assistant (**FinDuo Assist**) powered by a load-balanced Cerebras LLM engine.

---

## 🚀 Key Features

*   **👥 Dual-User Integration:** Built-in profiles and custom seeding for two primary users (Satya and Teja), supporting joint expense mapping and individual financial isolation where required.
*   **🏦 Comprehensive Account & Asset Management:** Real-time tracking of active/inactive bank accounts (e.g., Axis, SBI) and credit cards (limits, available balances, and usage ratios).
*   **📊 Amortization & Loan EMI Tracking:** Live management of active EMIs, loan timelines, and lenders (e.g., HDFC Home Loan, Axis Personal Loan, mobile financing).
*   **💸 Fixed & Variable Expense Budgets:** Manage recurring liabilities (Rent, Airtel, ACT, Electricity) alongside variable month-to-month utilities.
*   **⚡ Bulk Transaction Import with Deduplication:** Bulk transaction entry with smart deduplication using UPI transaction reference numbers (`txn_ref`) or fuzzy matching (same day + same amount) to eliminate double imports.
*   **🤖 FinDuo Assist (AI Financial Assistant):** A context-aware chat interface integrated directly with the user's financial profile. It uses a custom load-balanced **Cerebras LLM Manager** containing a pool of 65 API keys to securely analyze monthly spending, active loans, and balances, providing accurate, direct budgeting guidance.
*   **🎨 Glassmorphic Theme Engine:** The Flutter client supports **15 dynamic color themes**, **11 Google Fonts**, variable text scaling, and smooth animations using custom micro-interactions.

---

## 🛠️ Architecture & Tech Stack

### 1. Frontend (Client Application)
*   **Core Framework:** Flutter 3.x / Dart
*   **State Management:** Provider pattern (`SettingsProvider`, `AuthProvider`, `FinanceProvider`)
*   **Data Persistence:** Isar Database for offline storage, `shared_preferences`
*   **Styling & UI:** Glassmorphism, Google Fonts (`google_fonts: ^6.3.3`), and micro-animations (`flutter_animate`)
*   **Charts & Graphs:** High-fidelity analytics powered by `fl_chart`

### 2. Backend (API Server)
*   **Framework:** FastAPI (Python 3.9+)
*   **Web Server:** Uvicorn (running asynchronously on WSL or Native OS)
*   **Database:** PostgreSQL 14+ 
*   **Database Driver & ORM:** SQLAlchemy (Async Engine) + `asyncpg` for high-throughput connections
*   **Security:** OAuth2 password bearer token authentication, JWT (Jose), and Password hashing (`passlib` with `bcrypt`)
*   **AI SDK:** Custom async client for Cerebras API (`gpt-oss-120b` model)

---

## 📁 Project Directory Structure

```text
FinDuo/
├── APK/                    # Released Android package outputs (.apk)
├── backend/                # FastAPI application server
│   ├── auth.py             # User authentication and JWT helper functions
│   ├── main.py             # Router definitions, endpoints, and chat middleware
│   ├── database.py         # SQLAlchemy engine and AsyncSession configuration
│   ├── models.py           # PostgreSQL database schema (SQLAlchemy)
│   ├── schemas.py          # Pydantic data validation schemas
│   ├── seed_data.py        # Database resets and initial custom data seeds
│   ├── cerebras_manager.py # Multi-key load balancer for AI Chat completions
│   └── requirements.txt    # Python dependencies
├── frontend/               # Flutter mobile & desktop client
│   ├── lib/
│   │   ├── main.dart       # App entrypoint & Provider tree configuration
│   │   ├── screens/        # UI Views (Overview, Analytics, Spends, Admin, Chat Dialog)
│   │   ├── providers/      # Application state (Finance, Settings, Auth)
│   │   └── services/       # Dio API wrappers & background workers
│   └── pubspec.yaml        # Flutter project configuration & dependencies
├── scripts/                # Development & automation batch files
└── README.md               # Main repository documentation
```

---

## ⚙️ Local Development Setup

### Backend (FastAPI + PostgreSQL)

1.  **Start PostgreSQL:**
    Ensure PostgreSQL is installed and running on your database server. By default, the app looks for `postgresql+asyncpg://postgres:postgres@localhost:5432/finduo`. You can override this via the `DATABASE_URL` environment variable.

2.  **Setup Virtual Environment & Install Dependencies:**
    ```bash
    cd backend
    python -m venv venv
    venv\Scripts\activate
    pip install -r requirements.txt
    ```

3.  **Seed the Database:**
    To perform a fresh database setup and seed initial data:
    ```bash
    python seed_data.py
    ```

4.  **Run the Server:**
    ```bash
    uvicorn main:app --reload --host 0.0.0.0 --port 8001
    ```

---

### Frontend (Flutter Client)

1.  **Configure Dependencies:**
    Make sure you have Flutter installed and configured on your path. Get the required pub packages:
    ```bash
    cd frontend
    flutter pub get
    ```

2.  **Run in Debug Mode:**
    Ensure an Android emulator, physical device, or Windows target is connected.
    ```bash
    flutter run
    ```

3.  **Build a Release APK:**
    ```bash
    flutter build apk --release
    ```

---

## ⚡ Automation Scripts

The project includes pre-configured batch scripts under `scripts/` to streamline operations:

*   `0_seed_database.bat`: Completely drops existing tables and seeds fresh records (users, default accounts, categories, and bills).
*   `1_start_wsl_db.bat`: Starts the PostgreSQL service inside a WSL2 Ubuntu container and tails logs.
*   `2_start_backend.bat`: Launches the FastAPI server with live-reloads on port `8001`.
*   `3_start_android_app.bat`: Runs the Flutter app locally after listing available devices.
*   `4_build_android_apk.bat`: Builds the release version of the Android app and copies it directly to the root `/APK` folder.

---

## 🛡️ Security & API Integrity

*   **OAuth2 Protocol:** Secure API endpoints requiring authenticated JWT tokens (`Depends(get_current_user)`).
*   **Secure API Rotation:** `CerebrasManager` load-balances AI traffic across a set of active tokens, preventing rate limiting and ensuring high availability.
*   **Fuzzy Deduplication:** Multi-stage transaction filtering to avoid duplicate imports during SMS parse cycles.
