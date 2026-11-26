# Automated Job Posting Pipeline (v1) - dbt + DuckDB

[![dbt build & publish](https://github.com/Jones51/dbt-duckdb-pipeline/actions/workflows/dbt_build.yml/badge.svg?branch=master)](https://github.com/Jones51/dbt-duckdb-pipeline/actions/workflows/dbt_build.yml)

![dbt pipeline diagram](img/dbt_pipeline.png)

A public dbt + DuckDB pipeline over ~692k real job postings, rebuilt and republished automatically on every push.

- Models the raw postings into tested, documented insight marts
- Publishes the docs site and the finished warehouse — open to anyone, no credentials
- Runs itself on GitHub Actions: every push and every Monday

> **v1 of this pipeline** — everything free and local-friendly: DuckDB as the warehouse, GitHub Actions as the scheduler. [v2](../project_2/) rebuilds it production-grade on Databricks.

| What I Built | How I Implemented | Where to Look |
| --- | --- | --- |
| **dbt pipeline** | sources → `staging/` → `marts/` | [`analytics/models/`](analytics/models/) |
| **Data tests** | grain test (`unique` or composite key) + `not_null` on every mart | [`_marts.yml`](analytics/models/marts/_marts.yml) |
| **Hosted dbt docs** | lineage, descriptions, column tests | [Live docs site](https://jones51.github.io/dbt-duckdb-pipeline/) |
| **Public CI** | build + test + publish on every push | [Actions workflow](https://github.com/Jones51/dbt-duckdb-pipeline/actions) |
| **Environments** | local `dev` vs CI `prod` targets | [`ci/profiles.yml`](ci/profiles.yml) |
| **Published warehouse** | one `ATTACH`, queryable by anyone | [Query it](#query-the-published-warehouse) |

---

## ⚙️ The dbt Pipeline

Raw postings flow through three dbt layers — declared sources → cleaned staging views → insight marts — with tests gating every build. The DAG below is the whole flow:

![dbt dag diagram](img/dag_pipeline.png)

| Layer | Model | Grain | Materialization |
| --- | --- | --- | --- |
| Staging | `stg_job_postings` | one row per posting (error rows dropped) | view |
| Marts | `fct_postings_by_month_role` | one row per (month, role) | table |
| Marts | `fct_monthly_summary` | one row per month (totals + remote share) | table |
| Marts | `fct_top_locations` | one row per location (top 10) | table |

And the dbt features doing the work:

| dbt Feature | How I Used It |
| --- | --- |
| Declared sources (no hardcoded paths in SQL) | [`_sources.yml`](analytics/models/staging/_sources.yml) + `source('raw', 'job_postings')` |
| Model dependencies | `ref()` everywhere downstream; dbt resolves order and parallelism |
| Materializations | set per folder in [`dbt_project.yml`](analytics/dbt_project.yml): `staging/` → `view`, everything else → `table` |
| Data tests | every mart has a grain test: `unique` on `month` / `job_location`, and a composite-key test on (`month`, `role`) via a custom generic test ([`unique_combination_of_columns`](analytics/tests/generic/unique_combination_of_columns.sql)); `not_null` on keys and counts |
| Environments | local `dev` vs CI `prod` targets ([`ci/profiles.yml`](ci/profiles.yml)) |

`dbt build` compiles SQL, materializes models, and fails the run if any test fails — same command locally and in CI.

---

## 🚀 Production

GitHub Actions runs the whole pipeline — no laptop required: [`.github/workflows/dbt_build.yml`](.github/workflows/dbt_build.yml)

| Trigger | What happens |
| --- | --- |
| Push to `master` | Full rebuild |
| Weekly (Monday) | Scheduled rebuild — pipeline stays fresh |
| Manual (`workflow_dispatch`) | Run button in the Actions UI |

On each run, Actions:

1. Installs deps with `uv`
2. Downloads raw parquet
3. Runs `dbt build` with the committed CI profile (prod)
4. Publishes `prod.duckdb` as a GitHub Release asset

The badge at the top of this README links to the latest runs.

---

## 🦆 Query the published warehouse

No clone required. [Install DuckDB](https://duckdb.org/docs/installation/) (`brew install duckdb`), then from a `duckdb` session:

```sql
INSTALL httpfs;
LOAD httpfs;

ATTACH 'https://github.com/Jones51/dbt-duckdb-pipeline/releases/download/warehouse/prod.duckdb' AS jobs;
USE jobs;
SHOW TABLES;

SELECT * FROM fct_top_locations;
SELECT * FROM fct_monthly_summary;
```



---

## 📖 Docs

Docs are generated with `dbt docs generate` and published to GitHub Pages:

**→ [https://jones51.github.io/dbt-duckdb-pipeline/](https://jones51.github.io/dbt-duckdb-pipeline/)**

The site shows:

- The full **lineage graph** (sources → models → marts)
- **Model and column descriptions** from the YAML
- Which columns carry **tests**

---

## 💻 Run it yourself

```bash
uv sync
uv run python scripts/download_data.py
cd analytics && uv run dbt build
```

Optional docs locally:

```bash
uv run dbt docs generate
uv run dbt docs serve
```

---

## 📁 Project layout

```text
.
├── .github/workflows/dbt_build.yml   # public CI: build, test, publish
├── ci/profiles.yml                   # prod DuckDB target for Actions
├── data/                             # raw + warehouses (gitignored; CI regenerates)
├── docs/                             # dbt docs site (GitHub Pages)
├── analytics/
│   ├── dbt_project.yml
│   ├── models/
│   │   ├── staging/                  # _sources.yml, stg_job_postings (views)
│   │   └── marts/                    # fct_* models + tests (tables)
│   └── tests/generic/                # custom composite-key test
└── scripts/download_data.py          # fetch raw parquet before build
```

---