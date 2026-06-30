#!/bin/bash
# ============================================================================
# SKYPULSE AI — Automated Deployment Script
# ============================================================================
# Deploys the entire SkyPulse AI platform to your Snowflake account
# using SnowSQL CLI.
#
# Usage:
#   ./deploy.sh                    # Deploy everything (setup + model + data + features + ML)
#   ./deploy.sh --phase setup      # Only run infrastructure setup
#   ./deploy.sh --phase model      # Only run data model creation
#   ./deploy.sh --phase data       # Only load sample data
#   ./deploy.sh --phase features   # Only run feature showcases
#   ./deploy.sh --phase ml         # Only run AI/ML models
#   ./deploy.sh --phase demo       # Quick deploy: setup + model + data (enough for demo)
#
# Prerequisites:
#   - SnowSQL installed (brew install snowsql OR download from Snowflake)
#   - Connection configured in ~/.snowsql/config OR via environment variables
#   - ACCOUNTADMIN role access on your Snowflake account
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/sql"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/deploy_${TIMESTAMP}.log"

# SnowSQL connection (override with env vars or .env file)
SNOWSQL_CONNECTION="${SNOWSQL_CONNECTION:-skypulse}"
SNOWSQL_ACCOUNT="${SNOWFLAKE_ACCOUNT:-}"
SNOWSQL_USER="${SNOWFLAKE_USER:-}"
SNOWSQL_PASSWORD="${SNOWFLAKE_PASSWORD:-}"
SNOWSQL_ROLE="${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"
SNOWSQL_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-SKYPULSE_TRANSFORM_WH}"

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║   ✈️  SKYPULSE AI — Deployment Script                        ║"
    echo "║   Snowflake AI Innovation Day | London 2026                  ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${GREEN}[✓]${NC} ${message}" ;;
        WARN)  echo -e "${YELLOW}[!]${NC} ${message}" ;;
        ERROR) echo -e "${RED}[✗]${NC} ${message}" ;;
        STEP)  echo -e "${BLUE}[→]${NC} ${message}" ;;
        PHASE) echo -e "\n${CYAN}━━━ ${message} ━━━${NC}\n" ;;
    esac
    
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

check_snowsql() {
    if ! command -v snowsql &> /dev/null; then
        log ERROR "SnowSQL not found. Install it first:"
        echo ""
        echo "  macOS:   brew install --cask snowflake-snowsql"
        echo "  OR:      curl -O https://sfc-repo.snowflakecomputing.com/snowsql/bootstrap/1.3/darwin_arm64/snowsql-1.3.1-darwin_arm64.pkg"
        echo ""
        echo "  See: https://docs.snowflake.com/en/user-guide/snowsql-install-config"
        exit 1
    fi
    log INFO "SnowSQL found: $(snowsql --version 2>&1 | head -1)"
}

build_connection_args() {
    local args=""
    
    # If env vars are set, use them directly (overrides config file)
    if [[ -n "${SNOWSQL_ACCOUNT}" && -n "${SNOWSQL_USER}" ]]; then
        args="-a ${SNOWSQL_ACCOUNT} -u ${SNOWSQL_USER}"
        if [[ -n "${SNOWSQL_PASSWORD}" ]]; then
            args="${args} --authenticator snowflake_jwt 2>/dev/null || true"
        fi
    else
        # Use named connection from ~/.snowsql/config
        args="-c ${SNOWSQL_CONNECTION}"
    fi
    
    echo "${args}"
}

run_sql_file() {
    local file=$1
    local description=$2
    local relative_path="${file#${SCRIPT_DIR}/}"
    
    log STEP "Running: ${relative_path}"
    
    # Build snowsql command
    local conn_args=$(build_connection_args)
    
    if [[ -n "${SNOWSQL_ACCOUNT}" && -n "${SNOWSQL_USER}" && -n "${SNOWSQL_PASSWORD}" ]]; then
        # Direct connection with env vars
        snowsql \
            -a "${SNOWSQL_ACCOUNT}" \
            -u "${SNOWSQL_USER}" \
            -r "${SNOWSQL_ROLE}" \
            -f "${file}" \
            -o exit_on_error=true \
            -o output_format=plain \
            -o friendly=false \
            >> "${LOG_FILE}" 2>&1
    else
        # Named connection from config
        snowsql \
            -c "${SNOWSQL_CONNECTION}" \
            -r "${SNOWSQL_ROLE}" \
            -f "${file}" \
            -o exit_on_error=true \
            -o output_format=plain \
            -o friendly=false \
            >> "${LOG_FILE}" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        log INFO "Completed: ${relative_path}"
    else
        log ERROR "Failed: ${relative_path}"
        log ERROR "Check log file: ${LOG_FILE}"
        exit 1
    fi
}

run_phase() {
    local phase_dir=$1
    local phase_name=$2
    
    log PHASE "${phase_name}"
    
    if [ ! -d "${phase_dir}" ]; then
        log ERROR "Directory not found: ${phase_dir}"
        exit 1
    fi
    
    local file_count=$(find "${phase_dir}" -name "*.sql" | sort | wc -l | tr -d ' ')
    log INFO "Found ${file_count} SQL files to execute"
    
    for sql_file in $(find "${phase_dir}" -name "*.sql" | sort); do
        run_sql_file "${sql_file}" ""
    done
    
    log INFO "${phase_name} complete ✓"
}

run_verification() {
    log PHASE "VERIFICATION"
    log STEP "Checking row counts..."
    
    local verify_sql="
SELECT 'DIM_DATE' AS tbl, COUNT(*) AS rows FROM SKYPULSE_AI.SILVER.DIM_DATE
UNION ALL SELECT 'DIM_AIRPORT', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_AIRPORT
UNION ALL SELECT 'DIM_AIRCRAFT', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_AIRCRAFT
UNION ALL SELECT 'DIM_PASSENGER', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_PASSENGER
UNION ALL SELECT 'DIM_ROUTE', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_ROUTE
UNION ALL SELECT 'FACT_FLIGHT_EVENT', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT
UNION ALL SELECT 'FACT_BOOKING', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_BOOKING
UNION ALL SELECT 'FACT_DELAY', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_DELAY
UNION ALL SELECT 'FACT_FEEDBACK', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK
ORDER BY tbl;
"
    
    if [[ -n "${SNOWSQL_ACCOUNT}" && -n "${SNOWSQL_USER}" && -n "${SNOWSQL_PASSWORD}" ]]; then
        snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" \
            -q "${verify_sql}" -o output_format=plain -o friendly=false
    else
        snowsql -c "${SNOWSQL_CONNECTION}" -r "${SNOWSQL_ROLE}" \
            -q "${verify_sql}" -o output_format=plain -o friendly=false
    fi
    
    echo ""
    log INFO "Verification complete. Check counts above match expected values."
}

# ============================================================================
# Main Execution
# ============================================================================

print_banner

# Load .env file if it exists
if [ -f "${SCRIPT_DIR}/.env" ]; then
    log INFO "Loading configuration from .env file"
    export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
fi

# Create log directory
mkdir -p "${LOG_DIR}"
log INFO "Log file: ${LOG_FILE}"

# Check prerequisites
check_snowsql

# Parse arguments
PHASE="${1:-all}"
if [[ "$1" == "--phase" ]]; then
    PHASE="${2:-all}"
fi

# Confirm deployment
echo ""
echo -e "  Account:    ${YELLOW}${SNOWSQL_ACCOUNT:-'(from config: ${SNOWSQL_CONNECTION})'}${NC}"
echo -e "  Role:       ${YELLOW}${SNOWSQL_ROLE}${NC}"
echo -e "  Phase:      ${YELLOW}${PHASE}${NC}"
echo ""

if [[ "${SKIP_CONFIRM:-false}" != "true" ]]; then
    read -p "  Deploy to this account? (y/N): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log WARN "Deployment cancelled."
        exit 0
    fi
fi

echo ""
START_TIME=$(date +%s)

# Execute based on phase
case ${PHASE} in
    all)
        run_phase "${SQL_DIR}/01-setup" "PHASE 1: Infrastructure Setup"
        run_phase "${SQL_DIR}/02-data-model" "PHASE 2: Data Model"
        run_phase "${SQL_DIR}/03-sample-data" "PHASE 3: Sample Data"
        run_phase "${SQL_DIR}/04-features" "PHASE 4: Feature Showcases"
        run_phase "${SQL_DIR}/05-ai-ml" "PHASE 5: AI/ML Models"
        run_verification
        ;;
    setup)
        run_phase "${SQL_DIR}/01-setup" "PHASE 1: Infrastructure Setup"
        ;;
    model)
        run_phase "${SQL_DIR}/02-data-model" "PHASE 2: Data Model"
        ;;
    data)
        run_phase "${SQL_DIR}/03-sample-data" "PHASE 3: Sample Data"
        ;;
    features)
        run_phase "${SQL_DIR}/04-features" "PHASE 4: Feature Showcases"
        ;;
    ml)
        run_phase "${SQL_DIR}/05-ai-ml" "PHASE 5: AI/ML Models"
        ;;
    demo)
        log INFO "Quick demo deployment (setup + model + data)"
        run_phase "${SQL_DIR}/01-setup" "PHASE 1: Infrastructure Setup"
        run_phase "${SQL_DIR}/02-data-model" "PHASE 2: Data Model"
        run_phase "${SQL_DIR}/03-sample-data" "PHASE 3: Sample Data"
        run_verification
        ;;
    verify)
        run_verification
        ;;
    *)
        log ERROR "Unknown phase: ${PHASE}"
        echo "Valid phases: all, setup, model, data, features, ml, demo, verify"
        exit 1
        ;;
esac

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
log INFO "Deployment completed in ${DURATION} seconds"
log INFO "Full log: ${LOG_FILE}"
echo ""
echo -e "${GREEN}━━━ Ready for demo! Open presentation/DEMO_QUICKSTART.sql in Snowflake ━━━${NC}"
echo ""
