select
    pieces.piece_id,
    motifs.key as motif_name,
    motifs.value as motif
from {{ ref('pieces') }} as pieces,
    json_each(pieces.score -> 'motifs') as motifs
