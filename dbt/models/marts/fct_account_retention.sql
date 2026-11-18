with quotes as (
    select * from {{ ref('fct_quote_funnel') }}
),

account_weeks as (
    -- an account is active in a week when it submitted at least one quote
    select distinct
        account_id,
        date_trunc(date(submitted_at), week(monday)) as activity_week
    from quotes
    where is_submitted
),

cohorts as (
    select
        account_id,
        min(activity_week) as cohort_week
    from account_weeks
    group by account_id
),

data_end as (
    -- the last week of data is usually partial: measure up to the last complete week
    select
        date_sub(
            date_trunc(date_add(max(date(submitted_at)), interval 1 day), week(monday)),
            interval 1 week
        ) as last_complete_week
    from quotes
),

cohort_sizes as (
    select
        cohort_week,
        count(*) as cohort_size
    from cohorts
    group by cohort_week
),

cohort_grid as (
    -- one row per cohort and week, so weeks without activity show 0 instead of missing
    select
        cohort_sizes.cohort_week,
        cohort_sizes.cohort_size,
        weeks_since_first
    from cohort_sizes
    cross join data_end
    cross join unnest(
        generate_array(0, date_diff(data_end.last_complete_week, cohort_sizes.cohort_week, week(monday)))
    ) as weeks_since_first
),

cohort_activity as (
    select
        cohorts.cohort_week,
        date_diff(account_weeks.activity_week, cohorts.cohort_week, week(monday)) as weeks_since_first,
        count(*) as active_accounts
    from account_weeks
    inner join cohorts
        on account_weeks.account_id = cohorts.account_id
    group by cohorts.cohort_week, weeks_since_first
)

select
    cohort_grid.cohort_week,
    cohort_grid.weeks_since_first,
    date_add(cohort_grid.cohort_week, interval cohort_grid.weeks_since_first week) as activity_week,
    cohort_grid.cohort_size,
    coalesce(cohort_activity.active_accounts, 0) as active_accounts,
    coalesce(cohort_activity.active_accounts, 0) / cohort_grid.cohort_size as retention_rate
from cohort_grid
left join cohort_activity
    on cohort_grid.cohort_week = cohort_activity.cohort_week
    and cohort_grid.weeks_since_first = cohort_activity.weeks_since_first
