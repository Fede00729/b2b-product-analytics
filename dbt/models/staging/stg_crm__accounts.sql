with source as (
    select * from {{ source('raw', 'crm_accounts') }}
)

select
    cast(crm_account_id as string) as crm_account_id,
    initcap(company_name) as company_name,
    {{ normalize_domain('website_domain') }} as domain,
    segment as crm_segment,
    annual_revenue_usd,
    account_owner,
    cast(created_date as date) as crm_created_date
from source
