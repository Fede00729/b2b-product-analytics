with quotes as (
    select * from {{ ref('fct_quote_funnel') }}
),

data_range as (
    select
        min(date_trunc(date(form_started_at), week(monday))) as first_week,
        -- the last week of data is usually partial: stop at the last complete week
        date_sub(
            date_trunc(date_add(max(date(submitted_at)), interval 1 day), week(monday)),
            interval 1 week
        ) as last_complete_week
    from quotes
),

weeks as (
    -- one row per week, so weeks without activity show 0 instead of missing
    select week_start
    from data_range
    cross join unnest(
        generate_date_array(data_range.first_week, data_range.last_complete_week, interval 1 week)
    ) as week_start
),

started_quotes as (
    -- quotes by the week their form was opened
    select
        date_trunc(date(form_started_at), week(monday)) as week_start,
        count(*) as quotes_started,
        countif(is_submitted) as started_quotes_submitted
    from quotes
    group by week_start
),

submitted_quotes as (
    -- quotes by the week they were submitted: rates are computed on these same quotes
    select
        date_trunc(date(submitted_at), week(monday)) as week_start,
        count(*) as quotes_submitted,
        count(distinct account_id) as weekly_active_accounts,
        sum(carriers_requested) as carriers_requested,
        sum(carrier_quotes_returned) as carrier_quotes_returned,
        countif(has_carrier_response) as quotes_with_response,
        countif(is_bound) as quotes_bound,
        countif(is_client_submit_lost) as client_submits_lost
    from quotes
    where is_submitted
    group by week_start
),

bound_quotes as (
    -- North Star: policies by the week they were bound
    select
        date_trunc(date(bound_at), week(monday)) as week_start,
        count(*) as policies_bound
    from quotes
    where is_bound
    group by week_start
)

select
    weeks.week_start,
    coalesce(bound_quotes.policies_bound, 0) as policies_bound,
    coalesce(submitted_quotes.weekly_active_accounts, 0) as weekly_active_accounts,
    coalesce(started_quotes.quotes_started, 0) as quotes_started,
    coalesce(submitted_quotes.quotes_submitted, 0) as quotes_submitted,
    safe_divide(started_quotes.started_quotes_submitted, started_quotes.quotes_started) as quote_submit_rate,
    safe_divide(submitted_quotes.carrier_quotes_returned, submitted_quotes.carriers_requested) as carrier_response_rate,
    safe_divide(submitted_quotes.quotes_bound, submitted_quotes.quotes_with_response) as bind_rate,
    safe_divide(submitted_quotes.client_submits_lost, submitted_quotes.quotes_submitted) as client_tracking_loss
from weeks
left join started_quotes
    on weeks.week_start = started_quotes.week_start
left join submitted_quotes
    on weeks.week_start = submitted_quotes.week_start
left join bound_quotes
    on weeks.week_start = bound_quotes.week_start
