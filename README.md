# Oracle Biomedical Research DB Webapp

A Flask web application demonstrating an Oracle object-relational database schema and a simple CRUD / operations UI for managing donors, researchers, diseases, biological data, experiments, treatments, drugs, publications and related association entities. The project includes a full Oracle schema implemented with object types (REFs, SCOPE), triggers enforcing business rules, pipelined/table functions and stored procedures that implement five domain operations.

## Table of contents

- Project overview
- Features
- Repo structure
- Requirements
- Quick start (Docker)
- Running locally (without Docker)
- Database: schema and scripts
- Web application endpoints
- Notes, limitations and assumptions
- Contributing
- License

## Project overview

This repository contains:

- An Oracle object-relational schema (`sql/oracle_schema.sql`) modeling a biomedical research domain using Oracle object types, object tables and REF relationships.
- Stored procedures and operations (`sql/operations.sql`) that implement domain logic and reporting functions (Op1..Op5).
- A data population procedure (`sql/insert_auto.sql`) capable of generating synthetic test data at scale.
- A cleanup script (`sql/drop_oracle_schema.sql`) to drop schema objects.
- Unit-like test scripts for constraints and triggers (`sql/oracle_constraints_tests.sql`).
- A Flask web application (`webapp/app.py`) that provides HTML forms and pages to view and add entities and to run the defined operations.
- Docker support (Dockerfile + docker-compose.yml) and convenience PowerShell scripts to start/stop the webapp.

The app is configured to connect to an Oracle Database (XE or other) and expects an Oracle listener on the configured host/port/service.

## Features

- Object-oriented Oracle schema with types and object tables (donors, researchers, disease, biological_data, experiments, treatments, drugs, publications, future_works).
- Association tables modeled as object tables with REF columns (affected, analyze, assign, cause, writes, consider).
- Business rules enforced via CHECK constraints and row-level/compound triggers.
- Stored procedures for common operations and pipelined functions used by the web UI.
- A simple Bootstrap-like UI (templates in `webapp/templates`) to browse and insert data.
- Dockerized deployment for the web application (runs in Python 3.11 image). The app uses the oracledb Python driver in thin mode (no Instant Client required) by default.

## Repo structure

- `webapp/`
  - `app.py` - Flask application and routes
  - `config.py` - DB configuration (environment variables supported)
  - `requirements.txt` - Python dependencies
  - `Dockerfile` - container image for the webapp
  - `docker-compose.yml` - compose file (maps host DB by default to host.docker.internal)
  - `start.ps1`, `stop.ps1` - convenience PowerShell scripts to run the app with Docker
  - `templates/` - Jinja2 HTML templates for all views
  - `static/` - static assets and sample SQL for operations
- `sql/`
  - `oracle_schema.sql` - main schema (types, tables, triggers, indexes)
  - `operations.sql` - stored procedures and operation examples
  - `insert_auto.sql` - data population procedure
  - `drop_oracle_schema.sql` - cleanup script
  - `oracle_constraints_tests.sql` - test scripts for constraints and triggers
- `report.tex`, `img/` - auxiliary report and images used with the project

## Requirements

- Oracle Database (XE or Enterprise) accessible from the environment where the webapp runs. The Docker compose file expects the DB on `host.docker.internal:1521` with service `XEPDB1` and user `SYSTEM` by default. Adjust `DB_HOST`, `DB_PORT`, `DB_SERVICE`, `DB_USER` and `DB_PASSWORD` in environment variables or `webapp/config.py`.
- Python 3.11
- The Python dependencies in `webapp/requirements.txt` (Flask==3.x, oracledb, python-dotenv, Werkzeug)
- Docker & Docker Compose (for the easy docker-based launch)

## Quick start (Docker)

This is the recommended way to run the webapp locally if you have Docker Desktop and an Oracle DB container/listener on the host.

1. Start your Oracle DB container or ensure a reachable Oracle instance on host (e.g., Oracle XE running on host port 1521 with service `XEPDB1`).
2. From the `webapp` directory run (PowerShell):

   docker-compose up --build

The compose file sets `DB_HOST=host.docker.internal` so the container connects to the host's DB. If your DB runs in another container, adapt the `DB_HOST` and networking settings accordingly.

Open http://localhost:5000 in your browser.

## Running locally (without Docker)

1. Create a Python virtual environment and install dependencies:

   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r webapp\requirements.txt

2. Set environment variables (or edit `webapp/config.py`):

   $env:DB_HOST = 'localhost'
   $env:DB_PORT = '1521'
   $env:DB_SERVICE = 'XEPDB1'
   $env:DB_USER = 'SYSTEM'
   $env:DB_PASSWORD = 'Password123'

3. Run the app:

   cd webapp
   python app.py

App will be served on http://0.0.0.0:5000 (accessible at http://localhost:5000).

## Database: schema and scripts

1. Create the schema objects in your Oracle user by running `sql/oracle_schema.sql` in SQL*Plus or SQLcl. The script creates object types, tables and triggers in the connected schema.

   SQL> @sql/oracle_schema.sql

2. (Optional) Populate the schema with synthetic data using `sql/insert_auto.sql`. The script defines `PopulateDatabase` and calls it with sensible defaults. Review the procedure parameters before running if you want to customize dataset size.

   SQL> @sql/insert_auto.sql

3. Use `sql/operations.sql` to create stored procedures implementing the domain operations (proc_record_biological_data, proc_list_bio_below_density, proc_get_treatment_info, etc.). The Flask app expects these procedures/pipelined functions to exist and be callable.

4. To drop everything, execute `sql/drop_oracle_schema.sql`.

## Web application endpoints (high-level)

The Flask app exposes standard CRUD-like pages for the main entities. Key routes include:

- `/` - Home
- `/donors` - List donors
- `/donors/add` - Add donor
- `/researchers` - List researchers
- `/researchers/add` - Add researcher
- `/diseases`, `/diseases/add`
- `/biological_data`, `/biological_data/add`
- `/treatments`, `/treatments/add`
- `/drugs`, `/drugs/add`
- `/publications`, `/publications/add`
- `/allergies`, `/allergies/add`
- `/experiments`, `/experiments/add`
- `/future_works`, `/future_works/add`
- Association pages: `/assign`, `/writes`, `/affected`, `/cause`, `/analyze` (+ add pages)
- Operations: `/operations/op2`, `/operations/op3`, `/operations/op4`, `/operations/op5` (these call the database functions)

---
