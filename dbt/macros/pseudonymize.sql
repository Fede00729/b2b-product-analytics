{#
  Pseudonymize a personal identifier (e.g. email) with a salted SHA-256 hash.
  Same input + same salt -> same key, so joins still work,
  but the raw value never reaches the marts.
#}
{% macro pseudonymize(column) -%}
    to_hex(sha256(concat('{{ var("pii_salt") }}', lower(trim({{ column }})))))
{%- endmacro %}
