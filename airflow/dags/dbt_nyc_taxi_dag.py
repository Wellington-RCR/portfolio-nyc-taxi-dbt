from airflow.decorators import dag
from airflow.operators.bash import BashOperator
from pendulum import datetime


@dag(
    dag_id="nyc_taxi_dbt_pipeline",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["dbt", "nyc_taxi"],
)
def dbt_nyc_taxi_pipeline():

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command="source /usr/local/airflow/dbt_venv/bin/activate && cd /usr/local/airflow/dbt && dbt run --profiles-dir /usr/local/airflow/dbt_profile",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command="source /usr/local/airflow/dbt_venv/bin/activate && cd /usr/local/airflow/dbt && dbt test --profiles-dir /usr/local/airflow/dbt_profile",
    )

    dbt_run >> dbt_test


dbt_nyc_taxi_pipeline()