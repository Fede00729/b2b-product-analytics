with frontend_events as (
    select * from {{ ref('stg_app__frontend_events') }}
),

server_events as (
    select * from {{ ref('stg_app__server_events') }}
),

identity as (
    select * from {{ ref('int_identity__anonymous_to_user') }}
),

users as (
    select * from {{ ref('stg_app__users') }}
),

stitched_frontend_events as (
    select
        frontend_events.event_id,
        frontend_events.event_source,
        frontend_events.event_name,
        frontend_events.event_at,
        frontend_events.anonymous_id,
        -- pre-login events have no user_id: take it from identity stitching
        coalesce(frontend_events.user_id, identity.user_id) as user_id,
        frontend_events.user_id is null and identity.user_id is not null as is_user_id_stitched,
        frontend_events.quote_id,
        frontend_events.line_of_business,
        frontend_events.page_path,
        frontend_events.device_type
    from frontend_events
    left join identity
        on frontend_events.anonymous_id = identity.anonymous_id
),

client_events as (
    select
        stitched_frontend_events.event_id,
        stitched_frontend_events.event_source,
        stitched_frontend_events.event_name,
        stitched_frontend_events.event_at,
        stitched_frontend_events.anonymous_id,
        stitched_frontend_events.user_id,
        users.account_id,
        stitched_frontend_events.is_user_id_stitched,
        stitched_frontend_events.quote_id,
        stitched_frontend_events.line_of_business,
        cast(null as string) as carrier_id,
        cast(null as int64) as carriers_requested,
        cast(null as numeric) as premium_usd,
        stitched_frontend_events.page_path,
        stitched_frontend_events.device_type
    from stitched_frontend_events
    left join users
        on stitched_frontend_events.user_id = users.user_id
),

backend_events as (
    select
        event_id,
        event_source,
        event_name,
        event_at,
        cast(null as string) as anonymous_id,
        user_id,
        account_id,
        false as is_user_id_stitched,
        quote_id,
        line_of_business,
        carrier_id,
        carriers_requested,
        premium_usd,
        cast(null as string) as page_path,
        cast(null as string) as device_type
    from server_events
)

select * from client_events
union all
select * from backend_events
