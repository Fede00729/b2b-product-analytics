{{ config(severity='warn') }}

-- Known data quality issue: some policies are bound before the first carrier price
-- arrives, which is impossible. It warns instead of failing so it stays visible
-- in every build without blocking it.
select
    quote_id,
    first_carrier_return_at,
    bound_at,
    timestamp_diff(first_carrier_return_at, bound_at, hour) as hours_bound_too_early
from {{ ref('fct_quote_funnel') }}
where first_carrier_return_at > bound_at
