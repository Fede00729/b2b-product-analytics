"""
Synthetic data generator for QuoteBridge, a fictional B2B platform where
insurance agencies request quotes and carriers respond.

It produces four raw sources with the problems a real product team has:
  - front-end events keyed by an anonymous_id until the user logs in
  - server-side events keyed by internal user_id / account_id
  - app users with emails (personal data that must be pseudonymized)
  - CRM accounts keyed by a different id, matchable only by email domain,
    and with messy domains (upper case, "www.", trailing spaces)

Usage:
    python generator/generate_events.py --accounts 120 --days 120 --seed 42

Only the Python standard library is used.
"""

import argparse
import csv
import json
import random
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

LINES_OF_BUSINESS = ["commercial_auto", "general_liability", "workers_comp", "property", "cyber"]
SEGMENTS = ["small", "mid_market", "enterprise"]
ROLES = ["producer", "account_manager", "admin"]
DEVICES = ["desktop", "desktop", "desktop", "tablet", "mobile"]

# Funnel probabilities, by account segment (bigger agencies adopt more)
P_START_QUOTE = {"small": 0.30, "mid_market": 0.40, "enterprise": 0.50}
P_SUBMIT = 0.70
P_CARRIER_RETURNS = 0.85
P_BIND = 0.35


def ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def messy_domain(domain: str, rng: random.Random) -> str:
    """Return the CRM version of a domain: sometimes upper case, with www. or spaces."""
    variants = [domain, domain.upper(), f"www.{domain}", f" {domain} ", domain.title()]
    return rng.choice(variants)


def build_accounts(n: int, start: datetime, rng: random.Random):
    accounts, crm_rows = [], []
    for i in range(1, n + 1):
        domain = f"agency{i:03d}.example.com"
        segment = rng.choices(SEGMENTS, weights=[6, 3, 1])[0]
        created = start + timedelta(days=rng.randint(0, 60))
        account = {
            "account_id": f"acc_{i:04d}",
            "account_name": f"Agency {i:03d}",
            "domain": domain,
            "segment": segment,
            "created_at": created,
            # churn propensity: some accounts stop using the product
            "churn_after_days": rng.choice([None, None, None, rng.randint(20, 90)]),
        }
        accounts.append(account)
        # ~10% of accounts are missing from the CRM (a real-world gap to handle)
        if rng.random() > 0.10:
            crm_rows.append({
                "crm_account_id": f"001{rng.randint(10**11, 10**12 - 1)}",
                "company_name": account["account_name"].upper() if rng.random() < 0.3 else account["account_name"],
                "website_domain": messy_domain(domain, rng),
                "segment": segment,
                "annual_revenue_usd": rng.randint(200_000, 50_000_000),
                "account_owner": rng.choice(["sales_rep_a", "sales_rep_b", "sales_rep_c"]),
                "created_date": (created - timedelta(days=rng.randint(10, 200))).strftime("%Y-%m-%d"),
            })
    return accounts, crm_rows


def build_users(accounts, rng: random.Random):
    users = []
    n = 0
    for acc in accounts:
        size = {"small": (1, 3), "mid_market": (3, 8), "enterprise": (8, 20)}[acc["segment"]]
        for _ in range(rng.randint(*size)):
            n += 1
            signup = acc["created_at"] + timedelta(days=rng.randint(0, 20), hours=rng.randint(8, 18))
            users.append({
                "user_id": f"usr_{n:05d}",
                "account_id": acc["account_id"],
                "email": f"user{n}@{acc['domain']}",
                "role": rng.choice(ROLES),
                "signup_at": signup,
            })
    return users


def simulate(accounts, users, start: datetime, days: int, rng: random.Random):
    acc_by_id = {a["account_id"]: a for a in accounts}
    fe_events, srv_events = [], []

    def fe(anon, user_id, name, at, page, props=None, device="desktop"):
        fe_events.append({
            "message_id": str(uuid.UUID(int=rng.getrandbits(128))),
            "anonymous_id": anon,
            "user_id": user_id,
            "event_name": name,
            "event_ts": ts(at),
            "page_path": page,
            "device_type": device,
            "properties": json.dumps(props or {}),
        })

    def srv(user, name, at, props):
        srv_events.append({
            "event_id": str(uuid.UUID(int=rng.getrandbits(128))),
            "user_id": user["user_id"],
            "account_id": user["account_id"],
            "event_name": name,
            "event_ts": ts(at),
            "properties": json.dumps(props),
        })

    for user in users:
        acc = acc_by_id[user["account_id"]]
        anon = str(uuid.UUID(int=rng.getrandbits(128)))
        device = rng.choice(DEVICES)
        day = user["signup_at"]
        end = start + timedelta(days=days)
        if acc["churn_after_days"]:
            end = min(end, acc["created_at"] + timedelta(days=acc["churn_after_days"]))

        # First visit is anonymous (marketing site), then sign-up / login
        fe(anon, None, "page_viewed", day - timedelta(minutes=5), "/", device=device)
        srv(user, "user_signed_up", day, {"role": user["role"]})
        fe(anon, user["user_id"], "logged_in", day + timedelta(minutes=1), "/login", device=device)

        while day < end:
            # active on roughly 1 in 3 working days
            day += timedelta(days=rng.choice([1, 1, 2, 3, 5, 7]))
            if day >= end or day.weekday() >= 5:
                continue
            session_start = day.replace(hour=rng.randint(8, 18), minute=rng.randint(0, 59))
            t = session_start
            fe(anon, user["user_id"], "page_viewed", t, "/dashboard", device=device)

            if rng.random() < P_START_QUOTE[acc["segment"]]:
                quote_id = f"q_{uuid.UUID(int=rng.getrandbits(128)).hex[:12]}"
                lob = rng.choice(LINES_OF_BUSINESS)
                t += timedelta(minutes=rng.randint(1, 5))
                fe(anon, user["user_id"], "quote_form_started", t, "/quotes/new",
                   {"quote_id": quote_id, "line_of_business": lob}, device)

                if rng.random() < P_SUBMIT:
                    t += timedelta(minutes=rng.randint(3, 25))
                    # client-side click AND server-side confirmation: they won't always match
                    if rng.random() > 0.08:  # ad blockers / dropped client events
                        fe(anon, user["user_id"], "quote_submit_clicked", t, "/quotes/new",
                           {"quote_id": quote_id}, device)
                    n_carriers = rng.randint(1, 5)
                    srv(user, "quote_request_submitted", t + timedelta(seconds=2),
                        {"quote_id": quote_id, "line_of_business": lob, "carriers_requested": n_carriers})

                    returned = 0
                    for c in range(n_carriers):
                        if rng.random() < P_CARRIER_RETURNS:
                            returned += 1
                            srv(user, "carrier_quote_returned",
                                t + timedelta(hours=rng.randint(1, 72)),
                                {"quote_id": quote_id, "carrier_id": f"car_{rng.randint(1, 25):02d}",
                                 "premium_usd": round(rng.uniform(800, 60000), 2)})
                    if returned and rng.random() < P_BIND:
                        srv(user, "policy_bound", t + timedelta(days=rng.randint(1, 10)),
                            {"quote_id": quote_id, "line_of_business": lob})

    return fe_events, srv_events


def write_csv(path: Path, rows, fields):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: (ts(v) if isinstance(v, datetime) else v) for k, v in r.items() if k in fields})


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--accounts", type=int, default=120)
    p.add_argument("--days", type=int, default=120)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "data" / "raw"))
    args = p.parse_args()

    rng = random.Random(args.seed)
    start = datetime(2026, 7, 1, tzinfo=timezone.utc).replace(tzinfo=None)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    accounts, crm = build_accounts(args.accounts, start, rng)
    users = build_users(accounts, rng)
    fe_events, srv_events = simulate(accounts, users, start, args.days, rng)

    write_csv(out / "app_accounts.csv", accounts, ["account_id", "account_name", "domain", "segment", "created_at"])
    write_csv(out / "app_users.csv", users, ["user_id", "account_id", "email", "role", "signup_at"])
    write_csv(out / "crm_accounts.csv", crm, list(crm[0].keys()))
    write_csv(out / "frontend_events.csv", fe_events, list(fe_events[0].keys()))
    write_csv(out / "server_events.csv", srv_events, list(srv_events[0].keys()))

    print(f"accounts={len(accounts)} crm={len(crm)} users={len(users)} "
          f"frontend_events={len(fe_events)} server_events={len(srv_events)} -> {out}")


if __name__ == "__main__":
    main()
