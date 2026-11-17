with frontend_events as (
    select * from {{ ref('stg_app__frontend_events') }}
),

first_seen as (
    select
        anonymous_id,
        min(event_at) as first_seen_at
    from frontend_events
    group by anonymous_id
),

first_identification as (
    -- a device can be shared: keep the first user who logged in on it
    select
        anonymous_id,
        user_id,
        event_at as identified_at
    from frontend_events
    where user_id is not null
    qualify row_number() over (partition by anonymous_id order by event_at, user_id) = 1
)

select
    first_identification.anonymous_id,
    first_identification.user_id,
    first_seen.first_seen_at,
    first_identification.identified_at
from first_identification
inner join first_seen
    on first_identification.anonymous_id = first_seen.anonymous_id
