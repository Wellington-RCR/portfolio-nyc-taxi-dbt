FROM astrocrpublic.azurecr.io/runtime:3.3-7-python-3.12
RUN python -m venv dbt_venv && source dbt_venv/bin/activate && \
    pip install --no-cache-dir dbt-core==1.8.0 dbt-bigquery==1.8.0 && deactivate
