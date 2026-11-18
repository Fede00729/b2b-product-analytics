with events as (
    select * from {{ ref('int_events__unified') }}
),

quote_events as (
    select * from events
    where quote_id is not null
),

quotes as (
    select
        quote_id,
        -- every event of a quote shares account, user and line of business
        any_value(account_id) as account_id,
        any_value(user_id) as user_id,
        any_value(line_of_business) as line_of_business,
        min(case when event_name = 'quote_form_started' then event_at end) as form_started_at,
        min(case when event_name = 'quote_submit_clicked' then event_at end) as submit_clicked_at,
        min(case when event_name = 'quote_request_submitted' then event_at end) as submitted_at,
        min(case when event_name = 'carrier_quote_returned' then event_at end) as first_carrier_return_at,
        min(case when event_name = 'policy_bound' then event_at end) as bound_at,
        max(carriers_requested) as carriers_requested,
        countif(event_name = 'carrier_quote_returned') as carrier_quotes_returned
    from quote_events
    group by quote_id
)

select
    quote_id,
    account_id,
    user_id,
    line_of_business,
    form_started_at,
    submit_clicked_at,
    submitted_at,
    first_carrier_return_at,
    bound_at,
    carriers_requested,
    carrier_quotes_returned,
    timestamp_diff(first_carrier_return_at, submitted_at, hour) as hours_to_first_return,
    timestamp_diff(bound_at, submitted_at, day) as days_to_bind,
    submitted_at is not null as is_submitted,
    first_carrier_return_at is not null as has_carrier_response,
    bound_at is not null as is_bound,
    -- the server confirms the submit but the client click never arrived (ad blockers, closed tabs)
    submitted_at is not null and submit_clicked_at is null as is_client_submit_lost
from quotes
