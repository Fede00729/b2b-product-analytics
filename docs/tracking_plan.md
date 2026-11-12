# Tracking plan

QuoteBridge is a fictional B2B platform: insurance agencies request quotes, carriers respond, agencies bind policies.

## Identity

| Identifier | Where | Notes |
|---|---|---|
| `anonymous_id` | Client | Set on first visit. The only id before login. |
| `user_id` | Client (after login), server | Internal product user. |
| `account_id` | Server, app DB | Agency in the product. |
| `crm_account_id` | CRM | Different id. Matched to `account_id` through the normalized email/website domain. |
| `email` | App DB | Personal data. Pseudonymized in staging (salted SHA-256), never exposed in marts. |

## Events

| Event | Source | Trigger | Key properties |
|---|---|---|---|
| `page_viewed` | Client | Any page load | `page_path`, `device_type` |
| `logged_in` | Client | Successful login | links `anonymous_id` to `user_id` |
| `quote_form_started` | Client | User opens a new quote form | `quote_id`, `line_of_business` |
| `quote_submit_clicked` | Client | Submit button clicked | `quote_id` |
| `user_signed_up` | Server | Account user created | `role` |
| `quote_request_submitted` | Server | Quote request persisted | `quote_id`, `line_of_business`, `carriers_requested` |
| `carrier_quote_returned` | Server | A carrier returns a price | `quote_id`, `carrier_id`, `premium_usd` |
| `policy_bound` | Server | Agency binds a quote | `quote_id`, `line_of_business` |

## Why server-side

Business-critical steps (submitted, returned, bound) are tracked on the server: client events get lost to ad blockers and closed tabs. The generator drops ~8% of `quote_submit_clicked` on purpose, and `fct_quote_funnel` measures that gap.
