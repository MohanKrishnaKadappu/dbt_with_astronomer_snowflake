from datetime import datetime
from cosmos import ProjectConfig, ProfileConfig, ExecutionConfig, DbtDag
import os

# ---- DBT PROJECT PATH ----
# Inside your Airflow container, this should point to /usr/local/airflow/dbt
DBT_PROJECT_PATH = "/usr/local/airflow/dbt"

# ---- DBT EXECUTABLE PATH ----
#DBT_EXECUTABLE_PATH = f"{os.getenv('AIRFLOW_HOME')}/dbt_venv/bin/dbt"
DBT_EXECUTABLE_PATH = "/usr/local/bin/dbt"


# ---- PROJECT CONFIG ----dz
_project_config = ProjectConfig(
    dbt_project_path=DBT_PROJECT_PATH
)

# ---- PROFILE CONFIG (for Snowflake) ----
"""_profile_config = ProfileConfig(
    profile_name="my_dbt_project",  # must match your dbt_project.yml profile name
    target_name="dev",
    profile_args={
        "type": "snowflake",
        "account": "AZESRET-YVC38396",
        "user": "",
        "password": "",
        "role": "ACCOUNTADMIN",
        "database": "DBT_PRACTICE",
        "warehouse": "COMPUTE_WH",
        "schema": "RAW",
        "threads": 4,
        "client_session_keep_alive": False,
    },
)
"""

_profile_config = ProfileConfig(
    profile_name="dbt_project",
    target_name="dev",
    profiles_yml_filepath="/usr/local/airflow/dbt/profiles.yml",  # path inside container
)
# ---- EXECUTION CONFIG ----
_execution_config = ExecutionConfig(
    dbt_executable_path=DBT_EXECUTABLE_PATH
)

# ---- DAG DEFINITION ----
my_dag = DbtDag(
    dag_id="my_dag",
    project_config=_project_config,
    profile_config=_profile_config,
    execution_config=_execution_config,
    schedule="@daily",  # <-- correct argument name
    start_date=datetime(2025, 1, 1),
    max_active_tasks=1,
    catchup=False,
)
