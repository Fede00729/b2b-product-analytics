-- Fails for quotes whose funnel steps happen in an impossible order:
-- form started after submit, submit after the first carrier return,
-- or a bind without any carrier response.
-- Simpler row rules live as dbt_utils tests in _marts__models.yml.
select
    quote_id,
    form_started_at,
    submitted_at,
    first_carrier_return_at,
    bound_at
from {{ ref('fct_quote_funnel') }}
where form_started_at > submitted_at
    or submitted_at > first_carrier_return_at
    or (bound_at is not null and first_carrier_return_at is null)
