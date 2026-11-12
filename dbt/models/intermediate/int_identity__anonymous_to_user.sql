-- TODO (weekend): identity stitching.
-- One row per anonymous_id with the first user_id seen for it,
-- so pre-login events can be attributed to the user.
--
-- select anonymous_id, user_id
-- from stg_app__frontend_events
-- where user_id is not null
-- qualify row_number() over (partition by anonymous_id order by event_at) = 1
select 1 as placeholder
