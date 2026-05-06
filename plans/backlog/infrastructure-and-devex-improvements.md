# Infrastructure and DevEx Improvements

1. Change the `core` service command in `docker-compose` to boot Rails (or Foreman) instead of
   `sleep infinity`, enabling immediate dev usage.
2. Replace the hardcoded `trust` auth and static passwords in the Postgres services with
   environment-driven credentials, even for local development.
3. Swap the `rubocop -A` pre-commit hook for a safer variant (e.g., `--safe-auto-correct`) to reduce
   unintended edits from unsafe cops.
