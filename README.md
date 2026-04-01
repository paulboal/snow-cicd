# snow-cicd

Demonstration of Snowflake CI/CD automation with GitHub Actions.

**Workflow:** Feature branch -> Pull Request (auto-deploy to TEST) -> Merge to main (auto-deploy to PROD)

## Project Structure

```
snow-cicd/
├── .github/workflows/
│   ├── pr_test.yml              # PR -> deploy & test in TEST schema
│   └── merge_deploy.yml         # Merge -> deploy & smoke test in PROD schema
├── sql/
│   ├── 01_tables/               # Base table DDL
│   │   ├── 01_owner.sql
│   │   ├── 02_property.sql
│   │   └── 03_property_event.sql
│   ├── 02_dynamic_tables/       # Dynamic table (auto-refreshing aggregate)
│   │   └── 01_property_status_by_zip.sql
│   └── 03_seed_data/            # Sample data
│       └── 01_seed.sql
├── tests/
│   └── test_smoke.sql           # Validation queries
├── scripts/
│   └── deploy.sh                # Deployment orchestration
└── README.md
```

## Data Model

- **OWNER** - Property owners with category (INDIVIDUAL, INVESTOR, COMMERCIAL)
- **PROPERTY** - Residential properties with address, size, and zip code
- **PROPERTY_EVENT** - Status events (PURCHASE, ABANDONMENT, CONDEMNATION, APPROVED, DEMOLISHED)
- **PROPERTY_STATUS_BY_ZIP** - Dynamic table that pivots current property status counts by zip code

## Tools

This project uses the modern **Snowflake CLI** (`snow`) via the official
[`snowflakedb/snowflake-cli-action@v2.0`](https://github.com/snowflakedb/snowflake-cli-action)
GitHub Action. SQL files use `<% schema %>` client-side template variables,
substituted at runtime with `snow sql -D "schema=VALUE"`. Authentication uses
RSA key-pair via environment variables (no config file or key file needed).

## Setup Instructions

### 1. Snowflake Setup

Run the following in a Snowflake worksheet as ACCOUNTADMIN (or a role with sufficient privileges):

```sql
-- Create the database and schemas
CREATE DATABASE IF NOT EXISTS CICD_DEMO;
CREATE SCHEMA IF NOT EXISTS CICD_DEMO.TEST;
CREATE SCHEMA IF NOT EXISTS CICD_DEMO.PROD;

-- Create a warehouse for CI/CD
CREATE WAREHOUSE IF NOT EXISTS CICD_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Create a role for the CI/CD runner
CREATE ROLE IF NOT EXISTS CICD_ROLE;
GRANT USAGE ON DATABASE CICD_DEMO TO ROLE CICD_ROLE;
GRANT USAGE ON SCHEMA CICD_DEMO.TEST TO ROLE CICD_ROLE;
GRANT USAGE ON SCHEMA CICD_DEMO.PROD TO ROLE CICD_ROLE;
GRANT ALL ON SCHEMA CICD_DEMO.TEST TO ROLE CICD_ROLE;
GRANT ALL ON SCHEMA CICD_DEMO.PROD TO ROLE CICD_ROLE;
GRANT USAGE ON WAREHOUSE CICD_WH TO ROLE CICD_ROLE;

-- Create a service account user
CREATE USER IF NOT EXISTS CICD_RUNNER
    DEFAULT_ROLE = CICD_ROLE
    DEFAULT_WAREHOUSE = CICD_WH;

GRANT ROLE CICD_ROLE TO USER CICD_RUNNER;
```

### 2. Generate RSA Key Pair

On your local machine:

```bash
# Generate a private key (no passphrase for CI/CD simplicity)
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out cicd_rsa_key.p8 -nocrypt

# Extract the public key
openssl rsa -in cicd_rsa_key.p8 -pubout -out cicd_rsa_key.pub
```

Then assign the public key to the Snowflake user:

```sql
-- Copy the public key contents (without the BEGIN/END lines) and run:
ALTER USER CICD_RUNNER SET RSA_PUBLIC_KEY = '<paste-public-key-here>';
```

### 3. GitHub Repository Secrets

Go to your repo **Settings > Secrets and variables > Actions** and add these secrets:

| Secret Name | Value |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier (e.g. `rqb36878.us-east-1`) |
| `SNOWFLAKE_USER` | `CICD_RUNNER` |
| `SNOWFLAKE_WAREHOUSE` | `CICD_WH` |
| `SNOWFLAKE_PRIVATE_KEY_RAW` | The full contents of `cicd_rsa_key.p8` (including BEGIN/END lines) |

> **Note:** The old `SNOWFLAKE_PRIVATE_KEY` secret is no longer used. The Snowflake CLI action
> reads `SNOWFLAKE_PRIVATE_KEY_RAW` directly as an environment variable — no temp file needed.

### 4. Branch Protection

Go to your repo **Settings > Branches > Add rule**:

- **Branch name pattern:** `main`
- Check: **Require a pull request before merging**
- Check: **Require status checks to pass before merging**
  - Search for and select: `Deploy to TEST schema`
- Check: **Do not allow bypassing the above settings** (optional, for strict demo)

### 5. Test the Pipeline

```bash
# Create a feature branch
git checkout -b feature/initial-setup

# Add all the files and push
git add -A
git commit -m "Initial CI/CD demo setup"
git push -u origin feature/initial-setup

# Open a PR in GitHub -> watch the pr_test workflow run
# Merge the PR -> watch the merge_deploy workflow run
```

## How It Works

### On Pull Request (pr_test.yml)

1. Checks out the PR branch
2. Installs the Snowflake CLI via `snowflakedb/snowflake-cli-action@v2.0`
3. Runs `deploy.sh deploy TEST` — executes all SQL files against the **TEST** schema
4. Runs `deploy.sh test TEST` — executes smoke tests against **TEST**
5. Reports pass/fail as a GitHub check on the PR

### On Merge to Main (merge_deploy.yml)

1. Same process but targets the **PROD** schema
2. Smoke tests run after deployment to verify production

### deploy.sh

- Accepts two arguments: an action (`deploy` or `test`) and a schema name (`TEST` or `PROD`)
- Iterates through SQL directories in order (tables -> dynamic tables -> seed data)
- Runs each file via `snow sql -f <file> -D "schema=<SCHEMA>" -x`
  - `-D "schema=..."` substitutes `<% schema %>` template variables in the SQL
  - `-x` uses a temporary connection from `SNOWFLAKE_*` environment variables
- `deploy.sh test <SCHEMA>` forces a dynamic table refresh, runs smoke tests, and fails if any return `FAIL`

### Authentication

The workflows use RSA key-pair authentication via environment variables:

- `SNOWFLAKE_ACCOUNT` — account identifier
- `SNOWFLAKE_USER` — service account username
- `SNOWFLAKE_AUTHENTICATOR=SNOWFLAKE_JWT` — selects key-pair auth
- `SNOWFLAKE_PRIVATE_KEY_RAW` — RSA private key contents (injected from GitHub secret)
- `SNOWFLAKE_DATABASE` — target database
- `SNOWFLAKE_WAREHOUSE` — compute warehouse

No `config.toml`, no temp key files, no cleanup steps.

### Dynamic Table

The `PROPERTY_STATUS_BY_ZIP` dynamic table automatically computes the latest event
status for each property and pivots counts by zip code. It has a `TARGET_LAG = '1 minute'`.
The smoke tests force an immediate refresh via `ALTER DYNAMIC TABLE ... REFRESH` before
running assertions.
