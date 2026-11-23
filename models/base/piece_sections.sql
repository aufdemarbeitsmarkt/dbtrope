with written_sections as (
    select
        pieces.piece_id,
        sections.key as section_name,
        row_number() over (
            partition by pieces.piece_id
            order by sections.id
        ) as section_index,
        sections.value as section
    from {{ ref('pieces') }} as pieces,
        json_each(pieces.score -> 'sections') as sections
),

-- a piece written with voices and no sections is one section, main
voice_only_pieces as (
    select
        piece_id,
        'main' as section_name,
        1 as section_index,
        json_object('voices', score -> 'voices') as section
    from {{ ref('pieces') }}
    where (score -> 'sections') is null
)

select
    piece_id,
    section_name,
    section_index,
    section
from written_sections

union all

select
    piece_id,
    section_name,
    section_index,
    section
from voice_only_pieces
