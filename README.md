# dbt_with_astronomer_snowflake
This DBT project is integrated with Snowflake

# 🚀 End-to-End Setup Guide: Airflow + dbt (Cosmos) + Snowflake

This guide walks you through setting up, running, and verifying a **dbt + Snowflake project** orchestrated via **Astronomer Cosmos (Airflow)**. The document is copy-paste-ready and includes all commands, file contents, and Snowflake SQL you need.

---

## 🧰 Prerequisites

Before starting, ensure you have:

- Docker Desktop installed and running. See: https://docs.docker.com/desktop/
- Astronomer CLI installed (see below).
- Snowflake account with sufficient privileges (recommended: `ACCOUNTADMIN` for initial setup).
- A local machine with **Python 3.11+** for local development (we use 3.11 in examples).

---

## 🧩 Configuration Files (Setup Before Everything Else)

### Step 0 — Install Astronomer CLI

- **Windows (winget)**

```bash
winget install -e --id Astronomer.Astro
```

- **macOS (Homebrew)**

```bash
brew install astro
```

> The Astronomer CLI (`astro`) is required to create, run and deploy local Astro projects.


### Step 1 — Install Docker Desktop

Make sure Docker Desktop is installed and running. Follow the official guide:

https://docs.docker.com/desktop/setup/install/windows-install/


### Step 2 — Install Python 3.11 (minimum)

Install Python 3.11 or later (we use 3.11). Example download page:

https://www.python.org/downloads/release/python-3119/

After installing, confirm in a terminal:

```bash
python3.11 --version
# or on Windows
py -3.11 --version
```


### Step 3 — Create & activate a virtual environment (Windows example)

Run these commands from the project directory (do this **after** `astro dev init` as described below):

```powershell
py -3.11 -m venv venv
venv\Scripts\activate
python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt --no-cache-dir
```

> On macOS / Linux:
>
> ```bash
> python3.11 -m venv venv
> source venv/bin/activate
> python -m pip install --upgrade pip setuptools wheel
> pip install -r requirements.txt --no-cache-dir
> ```


### Step 4 — Initialize Astronomer Project

Create an empty folder where you want the Astro project and run:

```bash
mkdir demo_astro_snowflake
cd demo_astro_snowflake
astro dev init
```

This will create the project skeleton:

```
.
├── dags/
├── include/
├── Dockerfile
└── requirements.txt
```


### Step 5 — Minimal `requirements.txt` (copy into project root)

```txt
# Airflow + dbt + Cosmos + Snowflake integration
astronomer-cosmos==1.4.0

# Use a dbt core and adapter version compatible with Astro runtime
dbt-core==1.10.13
dbt-snowflake==1.10.2

# Airflow Snowflake provider for hooks/operators
apache-airflow-providers-snowflake==5.5.0

# Snowflake connector
snowflake-connector-python==3.18.0

# Optional
pandas
```

---

## 🧱 Dockerfile Configuration

Replace your project `Dockerfile` with the following minimal content:

```dockerfile
FROM astrocrpublic.azurecr.io/runtime:3.1-2

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt
```

Notes:
- We keep the image minimal and let Astronomer runtime supply Airflow.
- If you need dbt in a separate venv inside the image, add venv steps (see advanced sections). For now the runtime has `/usr/local/bin/dbt` installed by our `requirements.txt` choice.

---

## ❄️ Snowflake Setup (Run inside Snowflake Worksheet)

Use the SQL below to create the database, schemas, and sample raw tables used by the dbt project. **Run these in Snowflake** (in your account/role):

```sql
CREATE OR REPLACE DATABASE DBT_PRACTICE;
USE DATABASE DBT_PRACTICE;

CREATE OR REPLACE SCHEMA RAW;
CREATE OR REPLACE SCHEMA STAGING;
CREATE OR REPLACE SCHEMA MARTS;

-- RAW tables and sample data
CREATE OR REPLACE TABLE RAW.CUSTOMERS (
  ID INT,
  FIRST_NAME STRING,
  LAST_NAME STRING
);

INSERT INTO RAW.CUSTOMERS VALUES (1,'John','Doe'), (2,'Jane','Smith');

CREATE OR REPLACE TABLE RAW.ORDERS (
  ID INT,
  USER_ID INT,
  ORDER_DATE DATE,
  STATUS STRING
);

INSERT INTO RAW.ORDERS VALUES (1,1,'2023-01-01','completed'), (2,2,'2023-01-02','shipped');

CREATE OR REPLACE TABLE RAW.PAYMENTS (
  ID INT,
  ORDER_ID INT,
  PAYMENT_METHOD STRING,
  AMOUNT NUMBER(10,2)
);

INSERT INTO RAW.PAYMENTS VALUES (1,1,'credit_card',100),(2,2,'gift_card',50);
```

> Tip: If your dbt models reference different column names (for example `order_id` vs `id`) you must either change the raw tables to match expected column names or edit the dbt models (more on this later).

---

## 📁  dbt Project — Folder Structure (what to create locally)

Create `dbt/` inside your project root and copy the following structure:

```
dbt/
├── dbt_project.yml
├── profiles.yml
├── models/
│   ├── staging/
│   │   ├── stg_customers.sql
│   │   ├── stg_orders.sql
│   │   └── stg_payments.sql
│   └── marts/
│       ├── dim_customers.sql
│       └── fct_orders.sql
└── macros/
    └── generate_schema_name.sql
```

---

## 📘  dbt Configuration Files (copy & paste)

### `dbt/dbt_project.yml`

```yaml
name: 'dbt_project'
version: '1.0.0'
config-version: 2
require-dbt-version: ">=1.8.0"
profile: dbt_project

model-paths: ["models"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
clean-targets: ["target", "dbt_packages"]

models:
  dbt_project:
    staging:
      +database: DBT_PRACTICE
      +schema: STAGING
      +materialized: view
    marts:
      +database: DBT_PRACTICE
      +schema: MARTS
      +materialized: table
```


### `dbt/profiles.yml`

> Put this file under `dbt/profiles.yml` (or update the `profiles_yml_filepath` in your DAG to point where you placed it).

```yaml
dbt_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "<YOUR_ACCOUNT>"   # e.g. abcd-xy12345
      user: "<YOUR_USER>"
      password: "<YOUR_PASSWORD>" # or leave blank and configure Airflow connection
      role: "ACCOUNTADMIN"
      database: "DBT_PRACTICE"
      warehouse: "COMPUTE_WH"
      schema: "RAW"
      threads: 4
      client_session_keep_alive: False
```

---

## 🧩 dbt Models (copy & paste ready)

### `models/staging/stg_customers.sql`
```sql
select * from {{ source('raw', 'customers') }}
```

### `models/staging/stg_orders.sql`
```sql
select * from {{ source('raw', 'orders') }}
```

### `models/staging/stg_payments.sql`
```sql
select * from {{ source('raw', 'payments') }}
```

### `models/marts/fct_orders.sql`
```sql
with orders as (
    select * from {{ ref('stg_orders') }}
),
payments as (
    select * from {{ ref('stg_payments') }}
),
order_payments as (
    select
        order_id,
        sum(amount) as total_amount
    from payments
    group by order_id
)
select
    o.id as order_id,
    o.user_id as customer_id,
    o.order_date,
    o.status,
    p.total_amount as amount
from orders o
left join order_payments p on o.id = p.order_id
```

### `models/marts/dim_customers.sql`
```sql
with customers as (
    select * from {{ ref('stg_customers') }}
),
orders as (
    select * from {{ ref('stg_orders') }}
)
select
    c.id as customer_id,
    c.first_name,
    c.last_name,
    min(o.order_date) as first_order_date,
    max(o.order_date) as most_recent_order_date,
    count(o.id) as number_of_orders
from customers c
left join orders o on c.id = o.user_id
group by c.id, c.first_name, c.last_name
```

---

## 🔧 Optional Macro (generate_schema_name)

`macros/generate_schema_name.sql` (keep as-is) — used by dbt to choose schema:

```jinja
{% macro generate_schema_name(custom_schema, node) -%}
  {%- if custom_schema is not none and custom_schema != '' -%}
    {{ return(custom_schema) }}
  {%- endif -%}

  {%- set node_config_schema = (node.get('config') or {}).get('schema') -%}
  {%- if node_config_schema -%}
    {{ return(node_config_schema) }}
  {%- endif -%}

  {{ return(target.schema) }}
{%- endmacro %}
```

---

## ⚡ Airflow DAG: `dags/my_dag.py` (Cosmos — minimal)

Create a DAG file under `dags/my_dag.py` and paste the following:

```python
from datetime import datetime
from cosmos import ProjectConfig, ProfileConfig, ExecutionConfig, DbtDag

DBT_PROJECT_PATH = "/usr/local/airflow/dbt"
DBT_EXECUTABLE_PATH = "/usr/local/bin/dbt"

_project_config = ProjectConfig(dbt_project_path=DBT_PROJECT_PATH)

_profile_config = ProfileConfig(
    profile_name="dbt_project",
    target_name="dev",
    profiles_yml_filepath="/usr/local/airflow/dbt/profiles.yml",
)

_execution_config = ExecutionConfig(dbt_executable_path=DBT_EXECUTABLE_PATH)

my_dag = DbtDag(
    dag_id="my_dag",
    project_config=_project_config,
    profile_config=_profile_config,
    execution_config=_execution_config,
    schedule="@daily",
    start_date=datetime(2025, 1, 1),
    catchup=False,
)
```

Notes:
- `DbtDag` will parse the dbt project at DAG import time. If parsing takes long, Airflow may hit the DAG import timeout — see troubleshooting section.

---

## ▶️ Run Locally with Astronomer

1. Stop previous project (if running):

```bash
astro dev stop
```

2. Build and start the project:

```bash
astro dev start
```

3. Access Airflow UI at `http://localhost:8080`. Enable and trigger `my_dag`.

---

## ✅ Validate in Snowflake

In Snowflake, run:

```sql
SELECT * FROM DBT_PRACTICE.MARTS.FCT_ORDERS;
SELECT * FROM DBT_PRACTICE.MARTS.DIM_CUSTOMERS;
```

If both return result rows, your dbt models successfully materialized.

---

## 🛠 Troubleshooting & Tips

### 1) DAG Import Timeout (Cosmos runs `dbt ls` on import)

- Cosmos runs `dbt ls` to parse the project during DAG import. If that call takes longer than Airflow's DAG import timeout (30s by default), Airflow will raise a `DagBag import timeout` error. Fixes:
  - Keep the dbt project small (no large operations at top-level).
  - Ensure `git` is installed inside the container — dbt expects git for some operations.
  - Run `dbt ls` manually inside the container to measure timing.
  - Increase DAG import timeout in Airflow config (advanced).

### 2) Column name mismatches (common cause of SQL errors)

The Snowflake SQL errors you saw (invalid identifier `O.ID`, `USER_ID`) are caused by differences between the column names in your raw tables and the column names referenced in dbt models. Two options:

- Update your Snowflake raw tables to have the columns dbt expects (e.g., `id`, `user_id`, `order_id`).
- Modify dbt models to use the actual column names in your Snowflake raw tables.

Always keep raw table schema and dbt code aligned.

### 3) Git missing inside container

If `dbt debug` complains about `git`, install `git` in the Docker image or ensure it is present in the running container.

### 4) Dependency conflicts while building image

If `astro dev start` fails due to conflicting Python packages, pin versions in `requirements.txt` to match the Astronomer runtime or downgrade/upgrade dbt/cosmos accordingly.


### 5) Docker build failed to start due to previously running contaniner

If you see docker container build failed due to container already running etc, force stop the old container

docker stop $(docker ps -aq)
