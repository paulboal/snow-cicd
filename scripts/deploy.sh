#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# deploy.sh - Deploy SQL files to Snowflake via SnowSQL
#
# Required environment variables:
#   SNOWFLAKE_ACCOUNT        - Snowflake account identifier
#   SNOWFLAKE_USER           - Snowflake username
#   SNOWFLAKE_PRIVATE_KEY_PATH - Path to RSA private key file
#   SNOWFLAKE_DATABASE       - Target database (default: CICD_DEMO)
#   SNOWFLAKE_SCHEMA         - Target schema (TEST or PROD)
#   SNOWFLAKE_WAREHOUSE      - Warehouse to use
###############################################################################

SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-CICD_DEMO}"
SCHEMA="${SNOWFLAKE_SCHEMA:?SNOWFLAKE_SCHEMA must be set (TEST or PROD)}"
WAREHOUSE="${SNOWFLAKE_WAREHOUSE:?SNOWFLAKE_WAREHOUSE must be set}"
ACCOUNT="${SNOWFLAKE_ACCOUNT:?SNOWFLAKE_ACCOUNT must be set}"
USER="${SNOWFLAKE_USER:?SNOWFLAKE_USER must be set}"
PRIVATE_KEY_PATH="${SNOWFLAKE_PRIVATE_KEY_PATH:?SNOWFLAKE_PRIVATE_KEY_PATH must be set}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SNOWSQL_OPTS=(
    --accountname "$ACCOUNT"
    --username "$USER"
    --private-key-path "$PRIVATE_KEY_PATH"
    --dbname "$SNOWFLAKE_DATABASE"
    --schemaname "$SCHEMA"
    --warehouse "$WAREHOUSE"
    --option exit_on_error=true
    --option output_format=plain
    --option friendly=false
    --option header=true
)

run_sql_file() {
    local file="$1"
    local display_name="${file#$PROJECT_DIR/}"

    echo "========================================"
    echo "Deploying: $display_name"
    echo "  Schema:  $SNOWFLAKE_DATABASE.$SCHEMA"
    echo "========================================"

    # Replace __SCHEMA__ placeholder with actual schema name
    local tmp_file
    tmp_file=$(mktemp)
    sed "s/__SCHEMA__/${SCHEMA}/g" "$file" > "$tmp_file"

    snowsql "${SNOWSQL_OPTS[@]}" -f "$tmp_file"
    local rc=$?

    rm -f "$tmp_file"
    return $rc
}

ACTION="${1:-deploy}"

case "$ACTION" in
    deploy)
        echo ""
        echo "=== CICD_DEMO Deployment ==="
        echo "  Target: $SNOWFLAKE_DATABASE.$SCHEMA"
        echo "  Account: $ACCOUNT"
        echo "  User: $USER"
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
        echo "  Target: $SNOWFLAKE_DATABASE.$SCHEMA"
        echo ""

        # Replace schema placeholder in test file
        tmp_test=$(mktemp)
        sed "s/__SCHEMA__/${SCHEMA}/g" "$TEST_FILE" > "$tmp_test"

        # Run tests and capture output
        test_output=$(snowsql "${SNOWSQL_OPTS[@]}" -f "$tmp_test" 2>&1) || true
        rm -f "$tmp_test"

        echo "$test_output"
        echo ""

        # Check for any FAIL results
        if echo "$test_output" | grep -q "FAIL"; then
            echo "=== SMOKE TESTS FAILED ==="
            exit 1
        fi

        echo "=== All smoke tests passed ==="
        ;;

    *)
        echo "Usage: deploy.sh [deploy|test]"
        echo "  deploy  - Deploy SQL files to Snowflake (default)"
        echo "  test    - Run smoke tests against deployed schema"
        exit 1
        ;;
esac
