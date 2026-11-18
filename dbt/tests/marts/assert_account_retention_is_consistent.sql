-- Fails for cohort rows that break the retention table's rules:
-- duplicated grain (cohort_week, weeks_since_first), a rate outside 0-1,
-- more active accounts than the cohort, or a week 0 that is not 100%.
with retention as (
    select * from {{ ref('fct_account_retention') }}
),

duplicated_grain as (
    select
        cohort_week,
        weeks_since_first
    from retention
    group by cohort_week, weeks_since_first
    having count(*) > 1
)

select
    cohort_week,
    weeks_since_first,
    'duplicated grain' as issue
from duplicated_grain

union all

select
    cohort_week,
    weeks_since_first,
    'impossible rate' as issue
from retention
where retention_rate < 0
    or retention_rate > 1
    or active_accounts > cohort_size
    or (weeks_since_first = 0 and retention_rate != 1)
