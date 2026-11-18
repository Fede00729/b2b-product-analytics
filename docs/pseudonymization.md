# Pseudonymization

How QuoteBridge keeps personal data (user emails) out of the analytics layers, and why it is built this way.

## What the project does

In staging, `stg_app__users` replaces each email with a key and drops the raw email:

```sql
email_key = to_hex(sha256(concat(<secret>, lower(trim(email)))))
```

Only `email_key` and the email domain reach intermediate and marts. The same email always produces the same key, so users can still be counted and joined across tables. The logic lives in the macro [`pseudonymize`](../dbt/macros/pseudonymize.sql).

## Salt or pepper?

The secret is called `pii_salt` in the project, but strictly speaking it is a **pepper**, not a salt:

| | Salt | Pepper (what this project uses) |
|---|---|---|
| How many | A different random value **per record** | **One** shared value |
| Secret? | No, stored next to the hash | **Yes**, stored separately |
| Same input → same hash? | No | Yes |
| Typical use | Storing passwords | Pseudonymizing data that still needs joins |

A per-record salt is not an option here: the key has to be **deterministic** (same email → same key) to count unique users and join tables. A shared secret gives that, and it protects the keys from dictionary attacks: without the secret, nobody can hash a list of known emails and compare.

The variable keeps the name `pii_salt` because "salt" is how most data teams call it; renaming it to "pepper" would confuse more than it clarifies.

## What the guidelines recommend

| Source | Recommendation |
|---|---|
| **OWASP** Password Storage Cheat Sheet | Defines both terms: a salt is unique per credential and not secret; a pepper is a secret shared by all records and stored apart from the data (for example in a secrets vault) |
| **NIST** SP 800-63B | For stored secrets: a salt per record, plus an optional extra keyed step with a secret known only to the verifier, which is the pepper idea |
| **ENISA**, *Pseudonymisation techniques and best practices* (2019) | Plain or salted hashes are weak for pseudonymization. Prefers a **keyed hash (HMAC)** or encryption, with the key kept secret and separate from the data |
| **GDPR**, Article 4(5) | Data is pseudonymized only if the additional information needed to re-identify it (here, the secret) is **kept separately** and protected |

## What this project chose, and why

- **SHA-256 over secret + email** (a peppered hash). Deterministic, so joins work, and protected against dictionary attacks as long as the secret stays secret. Enough for a portfolio project with synthetic data.
- **The secret is kept separate from the data and the code:**
  - dev and CI use the placeholder `local-dev-salt` from `dbt_project.yml`;
  - prod gets the real value from the GitHub Actions secret `PII_SALT`, passed with `--vars`;
  - it is never committed.
- **dbt writes the secret into the compiled SQL**, so the compiled SQL must not be stored anywhere public or shared:
  - `stg_app__users` is materialized as a **table**, not a view, because a view stores its SQL;
  - the published dbt docs are generated with the placeholder, not the real secret.
- **Rotating the secret** changes every `email_key`. Nothing outside the warehouse stores these keys, so a full rebuild is enough.

## What production would use instead

- **HMAC-SHA256** (keyed hash), as ENISA recommends. BigQuery has no built-in HMAC function, so it would be a SQL user-defined function.
- Or **deterministic encryption** with a key managed in Cloud KMS (`DETERMINISTIC_ENCRYPT`). It is reversible only for whoever holds the key, and the key never appears in SQL.
- Plus regular rotation of the key and access to it restricted to the pipeline's service account.
