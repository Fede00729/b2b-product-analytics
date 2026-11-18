-- Fails for quotes whose funnel steps are out of order or impossible:
-- a later step before an earlier one, a bind without a carrier response,
-- or more carrier prices than carriers requested.
-- Bind before the first carrier return is a known issue, checked as a warning
-- in assert_quote_bound_after_first_carrier_return.sql.
select
    quote_id,
    form_started_at,
    submitted_at,
    first_carrier_return_at,
    bound_at,
    carriers_requested,
    carrier_quotes_returned
from {{ ref('fct_quote_funnel') }}
where form_started_at > submitted_at
    or submitted_at > first_carrier_return_at
    or (bound_at is not null and first_carrier_return_at is null)
    or carrier_quotes_returned > carriers_requested
