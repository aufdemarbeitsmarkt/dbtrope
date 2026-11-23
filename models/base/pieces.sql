select
    piece_id,
    file_path,
    (score ->> 'description') as description,
    coalesce((score ->> 'tempo')::double, 120) as tempo_bpm,
    coalesce(score ->> 'meter', '4/4') as meter,
    split_part(coalesce(score ->> 'meter', '4/4'), '/', 1)::integer as beats_per_bar,
    coalesce(score -> 'key' ->> 'root', 'C') as key_root,
    coalesce(score -> 'key' ->> 'scale', 'major') as scale_name,
    coalesce((score ->> 'seed')::bigint, 0) as seed,
    score
from {{ ref('piece_files') }}
