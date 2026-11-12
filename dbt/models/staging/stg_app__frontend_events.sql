with source as (
    select * from {{ source('raw', 'frontend_events') }}
)

select
    message_id                                   as event_id,
    anonymous_id,
    nullif(user_id, '')                          as user_id,
    event_name,
    cast(event_ts as timestamp)                  as event_at,
    page_path,
    device_type,
    json_value(properties, '$.quote_id')         as quote_id,
    json_value(properties, '$.line_of_business') as line_of_business,
    'client'                                     as event_source
from source
