# B2B product analytics: QuoteBridge

End-to-end product analytics for a fictional B2B workflow product, built with **Python, BigQuery and dbt**.

QuoteBridge lets insurance agencies request quotes from several carriers, compare them and bind a policy. This project answers the questions a product team asks: how many policies the platform drives (North Star), where users drop off in the quote funnel, which accounts keep coming back, and how much data client-side tracking loses compared to server-side.

> Status: work in progress. Data generator, tracking plan and staging layer done; identity stitching, funnel, retention and dashboard in progress.

## What it covers

- **Event tracking design:** a [tracking plan](docs/tracking_plan.md) with client-side and server-side events.
- **Identity resolution:** stitching `anonymous_id` → `user_id`, and matching product accounts to CRM accounts that use a different id and messy domains.
- **Pseudonymization:** emails are hashed with a salted SHA-256 in staging; no raw personal data reaches the marts.
- **Modeling in dbt:** staging → intermediate → marts, with tests and documentation.
- **Product metrics:** North Star, funnel, cohort retention ([definitions](docs/metrics.md)).
- **Dashboard:** Looker Studio on top of the marts.

## Architecture

```
generator (Python) ──► CSV ──► BigQuery (quotebridge_raw)
                                     │
                                     ▼  dbt
                    staging  ─►  intermediate  ─►  marts  ─►  Looker Studio
              (clean, pseudonymize)  (identity, CRM match)  (funnel, retention, North Star)
```

## Run it

```bash
# 1. Generate synthetic data (standard library only)
python generator/generate_events.py --accounts 120 --days 120 --seed 42

# 2. Load to BigQuery (sandbox / free tier is enough)
bq mk --location=US --dataset YOUR_GCP_PROJECT:quotebridge_raw
for t in app_accounts app_users crm_accounts frontend_events server_events; do
  bq load --replace --autodetect --source_format=CSV quotebridge_raw.$t data/raw/$t.csv
done

# 3. Build and test the models (dbt v2)
uv sync && source .venv/bin/activate
# add the block from dbt/profiles.example.yml to ~/.dbt/profiles.yml and set your project
cd dbt && dbt debug && dbt build              # dev
dbt build --target prod                      # prod
```

## Roadmap

- [x] Synthetic data generator with realistic tracking problems
- [x] Tracking plan and metric definitions
- [x] Staging models with pseudonymization and tests
- [ ] Identity stitching (`int_identity__anonymous_to_user`)
- [ ] Product ↔ CRM account matching with a match-rate test
- [ ] Quote funnel and client vs server tracking loss
- [ ] Weekly cohort retention
- [ ] North Star weekly metric
- [ ] Looker Studio dashboard + screenshots
