# SkyPulse AI — Setup & Deployment Guide

Complete step-by-step instructions to deploy the SkyPulse AI platform to your Snowflake account and push the project to GitHub.

---

## Prerequisites

| Requirement | Details |
|------------|---------|
| Snowflake Account | Enterprise Edition (Free Trial works) — AWS US West (Oregon) |
| SnowSQL CLI | Snowflake's command-line tool |
| Git | For version control and GitHub push |
| GitHub CLI (optional) | `gh` for creating repos from terminal |

---

## Step 1: Install SnowSQL

SnowSQL is Snowflake's official CLI that lets you run SQL files directly from your terminal.

**Option A: Homebrew (recommended for macOS)**
```bash
brew install --cask snowflake-snowsql
```

**Option B: Direct download**
```bash
# Apple Silicon (M1/M2/M3)
curl -O https://sfc-repo.snowflakecomputing.com/snowsql/bootstrap/1.3/darwin_arm64/snowsql-1.3.1-darwin_arm64.pkg
open snowsql-1.3.1-darwin_arm64.pkg
```

**Verify installation:**
```bash
snowsql --version
# Should output: Version: 1.3.x
```

---

## Step 2: Find Your Snowflake Account Identifier

1. Log into your Snowflake account at https://app.snowflake.com
2. Click your name/avatar (bottom-left corner)
3. Hover over your account — you'll see the **Account Identifier**
4. It looks like: `ORGNAME-ACCOUNTNAME` (e.g., `XYZCOMPANY-TRIAL123`)

Alternatively, run this in a Snowflake worksheet:
```sql
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
```

---

## Step 3: Configure Your Connection

**Option A: Using .env file (simplest for hackathon)**

```bash
cd skypulse-ai
cp .env.example .env
```

Edit `.env` with your details:
```bash
SNOWFLAKE_ACCOUNT=ORGNAME-ACCOUNTNAME
SNOWFLAKE_USER=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=ACCOUNTADMIN
```

**Option B: Using SnowSQL config (persistent)**

Edit `~/.snowsql/config` (create if it doesn't exist):
```ini
[connections.skypulse]
accountname = ORGNAME-ACCOUNTNAME
username = your_username
password = your_password
rolename = ACCOUNTADMIN
warehousename = SKYPULSE_TRANSFORM_WH
dbname = SKYPULSE_AI
```

Test the connection:
```bash
snowsql -c skypulse -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_ACCOUNT();"
```

---

## Step 4: Deploy to Snowflake

### Full deployment (all features + ML models)
```bash
./deploy.sh
```

### Quick demo deployment (just enough for the presentation)
```bash
./deploy.sh --phase demo
```

### Phase by phase (if you want control)
```bash
./deploy.sh --phase setup      # 1. Creates database, schemas, warehouses
./deploy.sh --phase model      # 2. Creates all tables (Bronze/Silver/Gold)
./deploy.sh --phase data       # 3. Loads sample data
./deploy.sh --phase features   # 4. Cortex AI, governance, sharing, alerts
./deploy.sh --phase ml         # 5. ML models (forecasting, anomaly, classification)
```

### Using Make (alternative)
```bash
make deploy          # Full deployment
make demo            # Quick demo deployment
make verify          # Check row counts
```

### Expected output
```
╔══════════════════════════════════════════════════════════════╗
║   ✈️  SKYPULSE AI — Deployment Script                        ║
╚══════════════════════════════════════════════════════════════╝

[✓] SnowSQL found: Version: 1.3.1
[✓] Loading configuration from .env file

  Account:    MYORG-MYTRIAL
  Role:       ACCOUNTADMIN
  Phase:      all

  Deploy to this account? (y/N): y

━━━ PHASE 1: Infrastructure Setup ━━━
[→] Running: sql/01-setup/001_database_setup.sql
[✓] Completed: sql/01-setup/001_database_setup.sql

━━━ PHASE 2: Data Model ━━━
[→] Running: sql/02-data-model/001_bronze_raw_tables.sql
...

[✓] Deployment completed in 127 seconds
━━━ Ready for demo! Open presentation/DEMO_QUICKSTART.sql in Snowflake ━━━
```

### Estimated time and credits
| Phase | Time | Credits |
|-------|------|---------|
| Setup | ~10s | 0.01 |
| Data Model | ~15s | 0.02 |
| Sample Data | ~60s | 0.1 |
| Features | ~45s | 0.1 |
| ML Models | ~120s | 0.3 |
| **Total** | **~4 min** | **~0.5** |

---

## Step 5: Verify Deployment

```bash
./deploy.sh --phase verify
```

Expected output:
```
DIM_DATE              ~1,096 rows
DIM_AIRPORT              20 rows
DIM_AIRCRAFT             16 rows
DIM_PASSENGER          ~500 rows
DIM_ROUTE                20 rows
FACT_FLIGHT_EVENT    ~5,000 rows
FACT_BOOKING        ~15,000 rows
FACT_DELAY             ~800 rows
FACT_FEEDBACK          ~500 rows
```

---

## Step 6: Push to GitHub

### Create the GitHub repo

**Option A: Using GitHub CLI (recommended)**
```bash
# Install gh if needed
brew install gh
gh auth login

# Create repo and push
cd skypulse-ai
gh repo create skypulse-ai --public --description "SkyPulse AI - Intelligent Airline Operations Platform on Snowflake" --source . --push
```

**Option B: Manual**
1. Go to https://github.com/new
2. Create repo named `skypulse-ai` (public, no README — we already have one)
3. Then from terminal:

```bash
cd skypulse-ai
git add -A
git commit -m "Initial commit: SkyPulse AI platform for Snowflake AI Innovation Day"
git remote add origin https://github.com/YOUR_USERNAME/skypulse-ai.git
git push -u origin main
```

---

## Step 7: Run the Live Demo

1. Open your Snowflake account in a browser
2. Go to **Worksheets**
3. Create a new worksheet
4. Paste the contents of `presentation/DEMO_QUICKSTART.sql`
5. Run each section during your presentation

Or if you prefer Snowflake Notebooks:
1. Go to **Notebooks** in the left nav
2. Create new notebook
3. Paste content from `sql/05-ai-ml/005_notebook_demo.sql` cell by cell

---

## Troubleshooting

### "Connection refused" or "Account not found"
- Double-check your account identifier format: `ORGNAME-ACCOUNTNAME`
- Don't include `.snowflakecomputing.com` — just the identifier
- Ensure you're using the full org-account format, not just the locator

### "Insufficient privileges"
- Make sure you're using `ACCOUNTADMIN` role
- On Free Trial accounts, ACCOUNTADMIN is available by default

### "Warehouse does not exist"
- Run `./deploy.sh --phase setup` first — it creates the warehouses
- If running scripts manually, execute `001_database_setup.sql` first

### "Object already exists"
- Scripts use `CREATE OR REPLACE` — safe to re-run
- If you want a clean slate: `make clean` then redeploy

### Cortex AI functions not available
- Cortex AI requires Enterprise Edition (included in Free Trial)
- Must be on AWS US West (Oregon), US East, or EU (Frankfurt)
- Check: `SELECT SNOWFLAKE.CORTEX.SENTIMENT('test');` — should return a number

### ML model training fails
- Ensure sufficient data exists (run Phase 3 first)
- ML training needs ~30+ data points per series
- Check warehouse size is at least SMALL for ML workloads

---

## Cleanup

When you're done with the hackathon:
```bash
make clean
# Type 'DELETE' to confirm
```

This drops the database and warehouses, stopping all credit usage.

---

## Project File Summary

| File | Purpose |
|------|---------|
| `deploy.sh` | Automated deployment script |
| `.env` | Your Snowflake credentials (git-ignored) |
| `Makefile` | Convenience commands |
| `RUN_ALL.sql` | Manual deployment reference |
| `README.md` | Project overview |
| `docs/ARCHITECTURE.md` | Technical design |
| `docs/semantic_model.yaml` | Cortex Analyst config |
| `presentation/PRESENTATION_OUTLINE.md` | Talk track |
| `presentation/DEMO_QUICKSTART.sql` | Live demo worksheet |
| `sql/01-setup/` | Infrastructure |
| `sql/02-data-model/` | Schema definitions |
| `sql/03-sample-data/` | Data generation |
| `sql/04-features/` | Feature showcases |
| `sql/05-ai-ml/` | ML models |
