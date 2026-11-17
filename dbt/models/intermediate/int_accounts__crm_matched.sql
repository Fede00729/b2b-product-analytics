with app_accounts as (
    select * from {{ ref('stg_app__accounts') }}
),

crm_accounts as (
    select * from {{ ref('stg_crm__accounts') }}
)

select
    app_accounts.account_id,
    app_accounts.account_name,
    app_accounts.domain,
    app_accounts.segment,
    app_accounts.created_at,
    crm_accounts.crm_account_id,
    crm_accounts.company_name as crm_company_name,
    crm_accounts.crm_segment,
    crm_accounts.annual_revenue_usd as crm_annual_revenue_usd,
    crm_accounts.account_owner as crm_account_owner,
    crm_accounts.crm_created_date,
    crm_accounts.crm_account_id is not null as is_crm_matched
from app_accounts
-- both domains are normalized in staging, so an exact match is enough
left join crm_accounts
    on app_accounts.domain = crm_accounts.domain
