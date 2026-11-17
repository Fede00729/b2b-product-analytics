with source as (
    select * from {{ source('raw', 'server_events') }}
)

select
    event_id,
    user_id,
    account_id,
    event_name,
    cast(event_ts as timestamp) as event_at,
    json_value(properties, '$.quote_id') as quote_id,
    json_value(properties, '$.line_of_business') as line_of_business,
    json_value(properties, '$.carrier_id') as carrier_id,
    cast(json_value(properties, '$.carriers_requested') as int64) as carriers_requested,
    cast(json_value(properties, '$.premium_usd') as numeric) as premium_usd,
    'server' as event_source
from source
