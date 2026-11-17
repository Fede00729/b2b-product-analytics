with source as (
    select * from {{ source('raw', 'app_accounts') }}
)

select
    account_id,
    account_name,
    {{ normalize_domain('domain') }} as domain,
    segment,
    cast(created_at as timestamp) as created_at
from source
