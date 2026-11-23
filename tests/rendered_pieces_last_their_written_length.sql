with written_lengths as (
    select
        piece_id,
        max(start_seconds + duration_seconds) as written_seconds
    from {{ ref('sections') }}
    group by piece_id
)

select
    written_lengths.piece_id,
    written_lengths.written_seconds,
    render_wav.duration_seconds
from written_lengths
left join {{ ref('render_wav') }} as render_wav
    on render_wav.piece_id = written_lengths.piece_id
where render_wav.piece_id is null
    or render_wav.sample_count < (written_lengths.written_seconds * render_wav.sample_rate)
