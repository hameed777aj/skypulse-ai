#!/bin/bash
# ============================================================================
# SKYPULSE AI — Automated Deployment Script
# ============================================================================
# Deploys the entire SkyPulse AI platform to your Snowflake account.
# Combines all SQL into a single file and executes with ONE MFA prompt.
#
# Usage:
#   ./deploy.sh                    # Deploy everything
#   ./deploy.sh --phase setup      # Only infrastructure
#   ./deploy.sh --phase model      # Only data model
#   ./deploy.sh --phase data       # Only sample data
#   ./deploy.sh --phase features   # Only feature showcases
#   ./deploy.sh --phase ml         # Only AI/ML models
#   ./deploy.sh --phase demo       # Quick: setup + model + data
#
# Prerequisites:
#   - SnowSQL installed (brew install --cask snowflake-snowsql)
#   - .env file configured with your Snowflake credentials
#   - ACCOUNTADMIN role access
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/sql"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/deploy_${TIMESTAMP}.log"
COMBINED_SQL="${LOG_DIR}/combined_${TIMESTAMP}.sql"

# Load .env
if [ -f "${SCRIPT_DIR}/.env" ]; then
    export $(grep -v '^#' "${SCRIPT_DIR}/.env" | grep -v '^\s*$' | xargs)
fi

# Connection settings
ACCOUNT="${SNOWFLAKE_ACCOUNT:-CXNOMFZ-UOB39323}"
USER="${SNOWFLAKE_USER:-HAMEED777AJ}"
ROLE="${SNOWFLAKE_ROLE:-ACCOUNTADMIN}"
WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH}"

# ============================================================================
# Functions
# ============================================================================

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║   ✈️  SKYPULSE AI — Automated Deployment                     ║"
    echo "║   Snowflake AI Innovation Day | London 2026                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    local level=$1; shift
    case $level in
        INFO)  echo -e "${GREEN}[✓]${NC} $@" ;;
        WARN)  echo -e "${YELLOW}[!]${NC} $@" ;;
        ERROR) echo -e "${RED}[✗]${NC} $@" ;;
        STEP)  echo -e "${BLUE}[→]${NC} $@" ;;
        PHASE) echo -e "\n${CYAN}━━━ $@ ━━━${NC}\n" ;;
    esac
}

check_snowsql() {
    if ! command -v snowsql &> /dev/null; then
        log ERROR "SnowSQL not found!"
        echo "  Install: brew install --cask snowflake-snowsql"
        exit 1
    fi
    log INFO "SnowSQL: $(snowsql --version 2>&1 | head -1)"
}

queue_phase() {
    local phase_dir=$1
    local phase_name=$2
    
    log PHASE "${phase_name}"
    
    if [ ! -d "${phase_dir}" ]; then
        log ERROR "Directory not found: ${phase_dir}"
        exit 1
    fi
    
    echo "" >> "${COMBINED_SQL}"
    echo "-- ================================================================" >> "${COMBINED_SQL}"
    echo "-- ${phase_name}" >> "${COMBINED_SQL}"
    echo "-- ================================================================" >> "${COMBINED_SQL}"
    echo "" >> "${COMBINED_SQL}"
    
    local count=0
    for sql_file in $(find "${phase_dir}" -name "*.sql" | sort); do
        local rel_path="${sql_file#${SCRIPT_DIR}/}"
        log STEP "Queuing: ${rel_path}"
        echo "" >> "${COMBINED_SQL}"
        echo "-- >>> ${rel_path}" >> "${COMBINED_SQL}"
        cat "${sql_file}" >> "${COMBINED_SQL}"
        echo "" >> "${COMBINED_SQL}"
        count=$((count + 1))
    done
    
    log INFO "${count} files queued for ${phase_name}"
}

add_verification() {
    cat >> "${COMBINED_SQL}" << 'EOF'

-- ================================================================
-- VERIFICATION
-- ================================================================
SELECT '━━━━━ DEPLOYMENT VERIFICATION ━━━━━' AS status;
SELECT 'DIM_DATE' AS table_name, COUNT(*) AS row_count FROM SKYPULSE_AI.SILVER.DIM_DATE
UNION ALL SELECT 'DIM_AIRPORT', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_AIRPORT
UNION ALL SELECT 'DIM_AIRCRAFT', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_AIRCRAFT
UNION ALL SELECT 'DIM_PASSENGER', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_PASSENGER
UNION ALL SELECT 'DIM_ROUTE', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_ROUTE
UNION ALL SELECT 'DIM_WEATHER', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_WEATHER
UNION ALL SELECT 'DIM_DELAY_REASON', COUNT(*) FROM SKYPULSE_AI.SILVER.DIM_DELAY_REASON
UNION ALL SELECT 'FACT_FLIGHT_EVENT', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_FLIGHT_EVENT
UNION ALL SELECT 'FACT_BOOKING', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_BOOKING
UNION ALL SELECT 'FACT_DELAY', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_DELAY
UNION ALL SELECT 'FACT_FEEDBACK', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_PASSENGER_FEEDBACK
UNION ALL SELECT 'FACT_LOYALTY', COUNT(*) FROM SKYPULSE_AI.SILVER.FACT_LOYALTY_ACTIVITY
ORDER BY table_name;
SELECT '━━━━━ DEPLOYMENT COMPLETE ━━━━━' AS status;
EOF
}

execute_combined() {
    local line_count=$(wc -l < "${COMBINED_SQL}" | tr -d ' ')
    
    echo ""
    log INFO "Combined SQL file: ${line_count} lines"
    log INFO "Connecting to Snowflake..."
    echo ""
    echo -e "  ${YELLOW}Enter your password with MFA code appended${NC}"
    echo -e "  ${YELLOW}Example: MyPassword123456 (where 123456 is your MFA code)${NC}"
    echo ""
    
    snowsql \
        -a "${ACCOUNT}" \
        -u "${USER}" \
        -r "${ROLE}" \
        -w "${WAREHOUSE}" \
        -f "${COMBINED_SQL}" \
        -o exit_on_error=false \
        -o output_format=plain \
        -o friendly=false \
        -o log_level=CRITICAL \
        --mfa-passcode-in-password \
        -P \
        2>&1 | tee -a "${LOG_FILE}"
    
    echo ""
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log INFO "Deployment completed successfully!"
    else
        log WARN "Deployment finished (some non-critical errors may have occurred)"
        log INFO "Check log: ${LOG_FILE}"
    fi
}

# ============================================================================
# Main
# ============================================================================

print_banner

mkdir -p "${LOG_DIR}"

check_snowsql

# Parse phase argument
PHASE="${1:-all}"
[[ "$1" == "--phase" ]] && PHASE="${2:-all}"

# Display config
echo -e "  Account:    ${YELLOW}${ACCOUNT}${NC}"
echo -e "  User:       ${YELLOW}${USER}${NC}"
echo -e "  Role:       ${YELLOW}${ROLE}${NC}"
echo -e "  Warehouse:  ${YELLOW}${WAREHOUSE}${NC}"
echo -e "  Phase:      ${YELLOW}${PHASE}${NC}"
echo ""

if [[ "${SKIP_CONFIRM:-}" != "true" ]]; then
    read -p "  Deploy to this account? (y/N): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log WARN "Cancelled."
        exit 0
    fi
fi

START_TIME=$(date +%s)

# Initialize combined SQL file
echo "-- SkyPulse AI Deployment - Generated $(date)" > "${COMBINED_SQL}"
echo "-- Phase: ${PHASE}" >> "${COMBINED_SQL}"
echo "" >> "${COMBINED_SQL}"

# Queue phases based on selection
case ${PHASE} in
    all)
        queue_phase "${SQL_DIR}/01-setup" "PHASE 1: Infrastructure Setup"
        queue_phase "${SQL_DIR}/02-data-model" "PHASE 2: Data Model"
        queue_phase "${SQL_DIR}/03-sample-data" "PHASE 3: Sample Data"
        queue_phase "${SQL_DIR}/04-features" "PHASE 4: Feature Showcases"
        queue_phase "${SQL_DIR}/05-ai-ml" "PHASE 5: AI/ML Models"
        add_verification
        ;;
    setup)
        queue_phase "${SQL_DIR}/01-setup" "PHASE 1: Infrastructure Setup"
        ;;
    model)
        queue_phase "${SQL_DIR}/02-data-model" "PHASE 2: Data Model"
        ;;
    data)
        queue_phase "${SQL_DIR}/03-sample-data" "PHASE 3: Sample Data"
        add_verification
        ;;
    features)
        queue_phase "${SQL_DIR}/04-features" "PHASE 4: Feature Showcases"
        ;;
    ml)
        queue_phase "${SQL_DIR}/05-ai-ml" "PHASE 5: AI/ML Models"
        ;;
    demo)
        log INFO "Quick demo deployment (setup + model + data)"
        queue_phase "${SQL_DIR}/01-setup" "PHASE 1: Infrastructure Setup"
        queue_phase "${SQL_DIR}/02-data-model" "PHASE 2: Data Model"
        queue_phase "${SQL_DIR}/03-sample-data" "PHASE 3: Sample Data"
        add_verification
        ;;
    verify)
        echo "USE DATABASE SKYPULSE_AI;" >> "${COMBINED_SQL}"
        add_verification
        ;;
    *)
        log ERROR "Unknown phase: ${PHASE}"
        echo "  Valid: all, setup, model, data, features, ml, demo, verify"
        exit 1
        ;;
esac

# Execute everything in ONE snowsql session (one MFA prompt)
execute_combined

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
log INFO "Total time: ${DURATION} seconds"
echo ""
echo -e "${GREEN}━━━ Ready for demo! Open presentation/DEMO_QUICKSTART.sql in Snowflake ━━━${NC}"
echo ""
