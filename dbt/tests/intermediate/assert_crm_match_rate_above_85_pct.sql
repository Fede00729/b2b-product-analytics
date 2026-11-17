-- Fails when fewer than 85% of product accounts find their CRM record.
-- A drop usually means a new domain format that normalize_domain doesn't handle.
with crm_match as (
    select countif(is_crm_matched) / count(*) as match_rate
    from {{ ref('int_accounts__crm_matched') }}
)

select match_rate
from crm_match
where match_rate < 0.85
