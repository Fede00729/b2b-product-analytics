with accounts as (
    select * from {{ ref('int_accounts__crm_matched') }}
),

users as (
    select * from {{ ref('stg_app__users') }}
),

quotes as (
    select * from {{ ref('fct_quote_funnel') }}
),

data_end as (
    -- measure recency against the end of the data, not today's date
    select max(submitted_at) as last_submitted_at
    from quotes
),

account_users as (
    select
        account_id,
        count(*) as users
    from users
    group by account_id
),

account_quotes as (
    select
        account_id,
        count(*) as quotes_started,
        countif(is_submitted) as quotes_submitted,
        countif(is_bound) as policies_bound,
        min(submitted_at) as first_quote_submitted_at,
        max(submitted_at) as last_quote_submitted_at
    from quotes
    group by account_id
)

select
    accounts.account_id,
    accounts.account_name,
    accounts.domain,
    accounts.segment,
    accounts.created_at,
    accounts.is_crm_matched,
    accounts.crm_account_id,
    accounts.crm_company_name,
    accounts.crm_segment,
    accounts.crm_annual_revenue_usd,
    accounts.crm_account_owner,
    coalesce(account_users.users, 0) as users,
    coalesce(account_quotes.quotes_started, 0) as quotes_started,
    coalesce(account_quotes.quotes_submitted, 0) as quotes_submitted,
    coalesce(account_quotes.policies_bound, 0) as policies_bound,
    account_quotes.first_quote_submitted_at,
    account_quotes.last_quote_submitted_at,
    coalesce(
        account_quotes.last_quote_submitted_at >= timestamp_sub(data_end.last_submitted_at, interval 28 day),
        false
    ) as is_active_last_4_weeks
from accounts
cross join data_end
left join account_users
    on accounts.account_id = account_users.account_id
left join account_quotes
    on accounts.account_id = account_quotes.account_id
