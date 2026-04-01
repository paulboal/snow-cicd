#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# deploy.sh - Deploy SQL files to Snowflake via Snowflake CLI (snow)
#
# Uses a temporary connection (-x) driven by SNOWFLAKE_* environment variables:
#   SNOWFLAKE_ACCOUNT          - Snowflake account identifier
#   SNOWFLAKE_USER             - Snowflake username
#   SNOWFLAKE_AUTHENTICATOR    - Auth method (e.g. SNOWFLAKE_JWT)
#   SNOWFLAKE_PRIVATE_KEY_RAW  - RSA private key contents (set by CLI action)
#   SNOWFLAKE_DATABASE         - Target database (default: CICD_DEMO)
#   SNOWFLAKE_WAREHOUSE        - Warehouse to use
#   SNOWFLAKE_ROLE             - Role to use (optional)
#
# The target schema is passed as a positional argument after the action.
#
# Usage:
#   deploy.sh deploy <SCHEMA>   - Deploy all SQL to the given schema
#   deploy.sh test <SCHEMA>     - Run smoke tests against the given schema
###############################################################################

ACTION="${1:?Usage: deploy.sh [deploy|test] <SCHEMA>}"
SCHEMA="${2:?Schema must be provided (TEST or PROD)}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Common snow sql options: temporary connection + variable substitution
run_sql_file() {
    local file="$1"
    local display_name="${file#$PROJECT_DIR/}"

    echo "========================================"
    echo "Running: $display_name"
    echo "  Schema: CICD_DEMO.$SCHEMA"
    echo "========================================"

    snow sql -f "$file" -D "schema=$SCHEMA" -x
}

case "$ACTION" in
    deploy)
        echo ""
        echo "=== CICD_DEMO Deployment ==="
        echo "  Target: CICD_DEMO.$SCHEMA"
        echo ""

        # Deploy in order: tables -> dynamic tables -> seed data
        for dir in "sql/01_tables" "sql/02_dynamic_tables" "sql/03_seed_data"; do
            full_dir="$PROJECT_DIR/$dir"
            if [ -d "$full_dir" ]; then
                for file in "$full_dir"/*.sql; do
                    [ -f "$file" ] || continue
                    run_sql_file "$file"
                done
            fi
        done

        echo ""
        echo "=== Deployment complete ==="
        ;;

    test)
        TEST_FILE="$PROJECT_DIR/tests/test_smoke.sql"

        if [ ! -f "$TEST_FILE" ]; then
            echo "ERROR: Test file not found: $TEST_FILE"
            exit 1
        fi

        echo ""
        echo "=== Running smoke tests ==="
        echo "  Target: CICD_DEMO.$SCHEMA"
        echo ""

        # Run tests and capture output
        test_output=$(snow sql -f "$TEST_FILE" -D "schema=$SCHEMA" -x 2>&1) || true

        echo "$test_output"
        echo ""

        # Check for any FAIL results in the output data.
        # Use "| FAIL" to match result rows in snow sql tabular output,
        # avoiding false positives from echoed SQL containing the string 'FAIL'.
        if echo "$test_output" | grep -qE "\|\s*FAIL\s*\|"; then
            echo "=== SMOKE TESTS FAILED ==="
            exit 1
        fi

        echo "=== All smoke tests passed ==="
        ;;

    *)
        echo "Usage: deploy.sh [deploy|test] <SCHEMA>"
        echo "  deploy  - Deploy SQL files to Snowflake"
        echo "  test    - Run smoke tests against deployed schema"
        exit 1
        ;;
esac
