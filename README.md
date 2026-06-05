# dbt_class — Medallion Architecture with dbt Core + Postgres

A dbt project that models customer data using the **Medallion Architecture** (Bronze → Silver → Gold). It runs on **dbt Core** with the **dbt-postgres** adapter and demonstrates incremental models, custom schema routing, and a clean staging → marts layering.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Folder Structure](#folder-structure)
- [The Layers Explained](#the-layers-explained)
  - [Staging (Silver) Layer](#staging-silver-layer)
  - [Marts (Gold) Layer](#marts-gold-layer)
- [Understanding `dbt_project.yml`](#understanding-dbt_projectyml)
- [Custom Schema Names](#custom-schema-names)
- [Setup Instructions (dbt Core + dbt-postgres)](#setup-instructions-dbt-core--dbt-postgres)
- [Running the Project](#running-the-project)
- [Security Note](#security-note)

---

## Architecture Overview

This project follows the **Medallion Architecture**, a layered data design that progressively refines data quality as it flows through the pipeline:

| Layer | dbt Folder | Schema | Purpose |
|-------|-----------|--------|---------|
| 🥉 **Bronze** | *(source)* | `public` | Raw, untouched source tables loaded into Postgres. Defined in `sources.yml`, not materialized by dbt. |
| 🥈 **Silver** | `models/staging` | `silver` | Cleaned & conformed data — casting, filtration, deduplication, and standardization. |
| 🥇 **Gold** | `models/marts` | `gold` | Business-ready dimensions and facts for analytics and reporting. |

```
   Raw Source (Bronze)          Staging (Silver)            Marts (Gold)
   ┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
   │ public.customer  │  ───►  │ stg_customer     │  ───►  │ dim_customer     │
   │ (raw load)       │        │ • cast types     │        │ • business logic │
   │                  │        │ • dedupe         │        │ • dimensions     │
   │                  │        │ • standardize    │        │ • facts          │
   │                  │        │ • filter         │        │                  │
   └──────────────────┘        └──────────────────┘        └──────────────────┘
```

---

## Folder Structure

```
dbt_class/
├── dbt_project.yml              # Project config: paths, materializations, schemas
├── profiles.yml                 # Connection config (Postgres credentials)
├── macros/
│   └── generate_schema_name.sql # Custom schema-naming override
├── models/
│   ├── staging/                 # 🥈 SILVER layer
│   │   ├── sources.yml          # Declares raw source tables (Bronze)
│   │   └── stg_customer.sql     # Cleaned customer staging model
│   └── marts/                   # 🥇 GOLD layer
│       └── dims/                # Dimension tables (business-ready)
├── seeds/                       # Static CSV reference data
├── snapshots/                   # Slowly Changing Dimension (SCD) tracking
├── tests/                       # Custom data tests
└── analyses/                    # Ad-hoc analytical queries
```

---

## The Layers Explained

### Staging (Silver) Layer

Located in `models/staging/`. This is where **raw data is cleaned and made trustworthy**. The staging layer is responsible for four core transformations:

1. **Casting** — converting columns to correct data types (e.g. strings → `int`, `date`, `numeric`).
2. **Filtration** — removing irrelevant, test, or invalid rows so only meaningful data flows downstream.
3. **Deduplication** — eliminating duplicate records (e.g. keeping the latest row per natural key using `ROW_NUMBER()` or `DISTINCT`).
4. **Standardization** — normalizing formats: trimming whitespace, lowercasing emails, unifying country codes, consistent casing for names, etc.

The staging model materializes as a **table** in the `silver` schema.

**Source declaration** (`models/staging/sources.yml`) — the Bronze layer is declared as a dbt *source* (raw table loaded externally), so models reference it via `{{ source('railway', 'customer') }}` rather than hardcoding table names:

```yaml
version: 2

sources:
  - name: railway
    description: "Customer table — name, address, phone, etc."
    schema: public
    tables:
      - name: customer
```

**Example staging model** (`models/staging/stg_customer.sql`) — uses an **incremental** materialization so only new/modified rows are processed on each run:

```sql
{{ config(materialized = 'incremental') }}

WITH src AS (
    SELECT *
    FROM {{ source('railway', 'customer') }}

    {% if is_incremental() %}
    WHERE modified_date > (SELECT MAX(modified_date) FROM {{ this }})
    {% endif %}
)
SELECT
    cust_id,
    name,
    address,
    phone_number,
    postal_code,
    country,
    email,
    father_name,
    mother_name,
    occupation,
    education,
    nationality
FROM src
```

> **Incremental models** only insert rows where `modified_date` is newer than the latest already loaded — making repeated runs fast and cheap. On a full refresh (`dbt run --full-refresh`), the table is rebuilt from scratch.

### Marts (Gold) Layer

Located in `models/marts/`. This is the **business-ready, consumption layer** — the data that analysts, dashboards, and reports actually query.

- `marts/dims/` holds **dimension tables** (e.g. `dim_customer`) — descriptive attributes joined and shaped for analysis.
- Marts apply business logic, joins, aggregations, and naming conventions meaningful to stakeholders.
- Materialized as **tables** in the `gold` schema for fast query performance.

Marts read **from staging models** (never directly from raw sources), keeping a clean dependency chain:

```sql
-- Example: models/marts/dims/dim_customer.sql
SELECT
    cust_id,
    name,
    country,
    occupation
FROM {{ ref('stg_customer') }}
```

---

## Understanding `dbt_project.yml`

`dbt_project.yml` is the **control center** of every dbt project. It tells dbt the project name, which profile to use for connections, where files live, and how each group of models should be built.

```yaml
# 1. Project identity
name: "dbt_class"          # Project name (lowercase + underscores only)
version: "1.0.0"

# 2. Which profile in profiles.yml to use for the DB connection
profile: "dbt_class"

# 3. Where dbt looks for each file type (defaults — rarely changed)
model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# 4. Folders removed by `dbt clean`
clean-targets:
  - "target"
  - "dbt_packages"

# 5. Model configuration by folder (the medallion routing)
models:
  dbt_class:                  # Must match the project `name` above
    marts:                    # 🥇 GOLD
      +materialized: table
      +schema: gold
    staging:                  # 🥈 SILVER
      +materialized: table
      +schema: silver
    seeds:
      +materialized: table
      +schema: seeds_schema
    snapshot:
      +materialized: table
      +schema: gold
```

**Key concepts:**

- The `+` prefix marks a **config key** (e.g. `+materialized`, `+schema`). Configs cascade: anything set on a folder applies to all models inside it, and can be overridden per-model with `{{ config(...) }}`.
- `+materialized` controls how a model is built: `view`, `table`, `incremental`, or `ephemeral`.
- `+schema` sets the **custom schema suffix** for that group of models (see next section).
- The top key under `models:` (`dbt_class`) **must exactly match** the `name:` of the project.

> ⚠️ **Indentation note:** YAML is whitespace-sensitive. The `marts.dims` block in the current file has its `+materialized`/`+schema` keys under `dims` slightly mis-indented — ensure each config key sits two spaces deeper than its parent folder so it nests correctly. The structure shown above is the corrected form.

---

## Custom Schema Names

By default, dbt **concatenates** your target schema and the model's custom schema (e.g. target `analytics` + custom `silver` → `analytics_silver`). This project overrides that behavior so the schema is used **as-is**.

`macros/generate_schema_name.sql`:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

**What this does:**

- If a model has **no** `+schema` config → it lands in the profile's default `schema` (`target.schema`).
- If a model **has** a `+schema` config → it lands in **exactly** that schema name (no prefix).

So with this macro:

| Model folder | `+schema` config | Resulting Postgres schema |
|--------------|------------------|---------------------------|
| `staging/`   | `silver`         | `silver`                  |
| `marts/`     | `gold`           | `gold`                    |
| `seeds/`     | `seeds_schema`   | `seeds_schema`            |

> Without this override, you'd get `defalut_schema_silver`, `defalut_schema_gold`, etc. — the macro gives you clean, predictable schema names that match the medallion layers.

dbt creates these schemas automatically if they don't already exist (assuming the connecting user has `CREATE` privileges).

---

## Setup Instructions (dbt Core + dbt-postgres)

### 1. Prerequisites

- **Python 3.9–3.12**
- **PostgreSQL** database you can connect to
- A terminal (this guide uses **PowerShell** on Windows)

### 2. Create and activate a virtual environment

```powershell
# From the project root
python -m venv venv
.\venv\Scripts\Activate.ps1
```

> On macOS/Linux: `python3 -m venv venv && source venv/bin/activate`

### 3. Install dbt Core and the Postgres adapter

```powershell
pip install dbt-core dbt-postgres
```

Verify the install:

```powershell
dbt --version
```

### 4. Configure your connection (`profiles.yml`)

dbt connects to Postgres using a **profile**. The profile name (`dbt_class`) must match the `profile:` value in `dbt_project.yml`.

> dbt looks for `profiles.yml` in `~/.dbt/profiles.yml` (i.e. `C:\Users\<you>\.dbt\profiles.yml` on Windows) by default. A copy in the project root also works if you point `DBT_PROFILES_DIR` at it, but the standard location keeps credentials out of the repo.

Recommended `profiles.yml` (use **environment variables** instead of plaintext secrets):

```yaml
dbt_class:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('DBT_PG_HOST') }}"
      port: "{{ env_var('DBT_PG_PORT') | int }}"
      user: "{{ env_var('DBT_PG_USER') }}"
      pass: "{{ env_var('DBT_PG_PASSWORD') }}"
      dbname: "{{ env_var('DBT_PG_DBNAME') }}"
      schema: default_schema    # fallback schema when a model has no +schema
      threads: 1
```

Set the variables before running dbt (PowerShell):

```powershell
$env:DBT_PG_HOST     = "your-host"
$env:DBT_PG_PORT     = "5432"
$env:DBT_PG_USER     = "postgres"
$env:DBT_PG_PASSWORD = "your-password"
$env:DBT_PG_DBNAME   = "your-db"
```

**Field reference:**

| Field | Meaning |
|-------|---------|
| `type` | Adapter — `postgres` |
| `host` | Database host / proxy address |
| `port` | Postgres port (default `5432`) |
| `user` / `pass` | Database credentials |
| `dbname` | Target database |
| `schema` | Default schema (used when a model sets no `+schema`) |
| `threads` | Number of models dbt builds in parallel |

### 5. Test the connection

```powershell
dbt debug
```

A green **"All checks passed!"** confirms dbt can reach your Postgres instance.

---

## Running the Project

```powershell
# Install any package dependencies (if a packages.yml exists)
dbt deps

# Load seed CSVs into the warehouse
dbt seed

# Build all models (staging → marts)
dbt run

# Build only the staging (silver) layer
dbt run --select staging

# Build only the marts (gold) layer
dbt run --select marts

# Force a full rebuild of incremental models
dbt run --full-refresh

# Run data tests
dbt test

# Generate and serve documentation
dbt docs generate
dbt docs serve
```

**Typical workflow:** `dbt seed` → `dbt run` → `dbt test`.

---

## Security Note

> ⚠️ The `profiles.yml` currently committed to this repo contains a **live database host, port, and password in plaintext**. You should:
> 1. **Rotate that password immediately** (assume it is compromised).
> 2. Move `profiles.yml` out of the repo to `~/.dbt/profiles.yml`, or use `env_var()` as shown above.
> 3. Add `profiles.yml` to `.gitignore` so credentials are never committed.

---

## Resources

- [dbt Documentation](https://docs.getdbt.com/docs/introduction)
- [dbt-postgres adapter](https://docs.getdbt.com/docs/core/connect-data-platform/postgres-setup)
- [Custom schemas in dbt](https://docs.getdbt.com/docs/build/custom-schemas)
- [Incremental models](https://docs.getdbt.com/docs/build/incremental-models)
