select
    scale_name,
    list(semitones_above_root order by scale_degree) as semitones_above_root,
    count(*) as degree_count
from {{ ref('scales') }}
group by scale_name
