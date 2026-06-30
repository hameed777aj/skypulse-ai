# ============================================================================
# SKYPULSE AI — Makefile
# ============================================================================
# Convenience commands for deployment and development.
#
# Usage:
#   make deploy        — Full deployment (all phases)
#   make demo          — Quick deploy (setup + model + data)
#   make ml            — Deploy only AI/ML models
#   make verify        — Check row counts
#   make clean         — Tear down the database (DESTRUCTIVE!)
#   make install-deps  — Install SnowSQL
#   make help          — Show all commands
# ============================================================================

.PHONY: help deploy demo setup model data features ml verify clean install-deps push

# Default target
help:
	@echo ""
	@echo "  SkyPulse AI — Available Commands"
	@echo "  ─────────────────────────────────────────"
	@echo ""
	@echo "  Deployment:"
	@echo "    make deploy        Full deployment (all 5 phases)"
	@echo "    make demo          Quick deploy (setup + model + data)"
	@echo "    make setup         Phase 1: Infrastructure only"
	@echo "    make model         Phase 2: Data model only"
	@echo "    make data          Phase 3: Sample data only"
	@echo "    make features      Phase 4: Feature showcases only"
	@echo "    make ml            Phase 5: AI/ML models only"
	@echo ""
	@echo "  Operations:"
	@echo "    make verify        Check deployment (row counts)"
	@echo "    make clean         DROP DATABASE (destructive!)"
	@echo ""
	@echo "  Setup:"
	@echo "    make install-deps  Install SnowSQL CLI"
	@echo "    make env           Create .env from example"
	@echo ""
	@echo "  Git:"
	@echo "    make push          Commit and push to GitHub"
	@echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Deployment Commands
# ─────────────────────────────────────────────────────────────────────────────

deploy:
	@./deploy.sh --phase all

demo:
	@./deploy.sh --phase demo

setup:
	@./deploy.sh --phase setup

model:
	@./deploy.sh --phase model

data:
	@./deploy.sh --phase data

features:
	@./deploy.sh --phase features

ml:
	@./deploy.sh --phase ml

verify:
	@./deploy.sh --phase verify

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup (DESTRUCTIVE)
# ─────────────────────────────────────────────────────────────────────────────

clean:
	@echo ""
	@echo "  ⚠️  This will DROP the SKYPULSE_AI database and all warehouses!"
	@echo ""
	@read -p "  Type 'DELETE' to confirm: " confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		echo "DROP DATABASE IF EXISTS SKYPULSE_AI; DROP DATABASE IF EXISTS WEATHER_MARKETPLACE_DEMO; DROP WAREHOUSE IF EXISTS SKYPULSE_INGEST_WH; DROP WAREHOUSE IF EXISTS SKYPULSE_TRANSFORM_WH; DROP WAREHOUSE IF EXISTS SKYPULSE_ANALYTICS_WH; DROP WAREHOUSE IF EXISTS SKYPULSE_ML_WH;" | \
		snowsql -c $${SNOWSQL_CONNECTION:-skypulse} -r ACCOUNTADMIN -o friendly=false; \
		echo "  ✓ Cleanup complete"; \
	else \
		echo "  Cancelled."; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Setup Helpers
# ─────────────────────────────────────────────────────────────────────────────

install-deps:
	@echo "Installing SnowSQL..."
	@if command -v brew &> /dev/null; then \
		brew install --cask snowflake-snowsql; \
	else \
		echo "Homebrew not found. Download SnowSQL from:"; \
		echo "  https://developers.snowflake.com/snowsql/"; \
	fi
	@echo ""
	@echo "Verify installation:"
	@snowsql --version 2>&1 || true

env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "  ✓ Created .env from .env.example"; \
		echo "  → Edit .env with your Snowflake credentials"; \
	else \
		echo "  .env already exists. Edit it directly."; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# Git / GitHub
# ─────────────────────────────────────────────────────────────────────────────

push:
	@git add -A
	@git commit -m "Update SkyPulse AI platform" || true
	@git push -u origin main
