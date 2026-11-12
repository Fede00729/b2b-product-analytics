{# Normalize a website/email domain so CRM and app identifiers can be matched. #}
{% macro normalize_domain(column) -%}
    regexp_replace(lower(trim({{ column }})), r'^www\.', '')
{%- endmacro %}
