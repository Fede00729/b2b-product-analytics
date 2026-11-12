with source as (
    select * from {{ source('raw', 'app_users') }}
)

select
    user_id,
    account_id,
    {{ pseudonymize('email') }}                     as email_key,     -- raw email is dropped here
    {{ normalize_domain("split(email, '@')[safe_offset(1)]") }} as email_domain,
    role,
    cast(signup_at as timestamp)                    as signed_up_at
from source
