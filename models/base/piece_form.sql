with written_forms as (
    select
        piece_id,
        -- an empty form counts as leaving it out
        nullif(from_json(score -> 'form', '["varchar"]'), []) as section_names
    from {{ ref('pieces') }}
),

written_form_entries as (
    select
        piece_id,
        unnest(section_names) as section_name,
        generate_subscripts(section_names, 1) as form_index
    from written_forms
),

sections as (
    select
        piece_id,
        section_name,
        section_index
    from {{ ref('piece_sections') }}
),

-- without a form, a piece plays each section once, in the order written
default_form_entries as (
    select
        sections.piece_id,
        sections.section_name,
        sections.section_index as form_index
    from sections
    join written_forms
        on written_forms.piece_id = sections.piece_id
    where written_forms.section_names is null
),

form_entries as (
    select
        piece_id,
        form_index,
        section_name
    from written_form_entries

    union all

    select
        piece_id,
        form_index,
        section_name
    from default_form_entries
)

select
    form_entries.piece_id,
    form_entries.form_index,
    form_entries.section_name,
    (sections.section_name is not null) as is_section_defined
from form_entries
left join sections
    on sections.piece_id = form_entries.piece_id
    and sections.section_name = form_entries.section_name
