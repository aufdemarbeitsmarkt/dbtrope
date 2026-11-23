import json
from pathlib import Path

import yaml


def selected_paths(pieces_dir, piece):
    """Every piece file in pieces_dir, or only the one the piece var names:
    a piece name (nocturne) or a path to a .yml file anywhere."""
    if not piece:
        return sorted(pieces_dir.glob("*.yml"))
    path = Path(piece).expanduser()
    if path.suffix not in (".yml", ".yaml"):
        path = pieces_dir / f"{piece}.yml"
    if not path.is_file():
        raise FileNotFoundError(f"piece {piece!r}: {path} doesn't exist")
    return [path]


def model(dbt, session):
    dbt.config(materialized="table")
    pieces_dir = Path(dbt.config.get("pieces_dir"))
    # dbt only passes config keys it finds in plain dbt.config.get() calls
    piece = dbt.config.get("piece")
    piece = (piece or "").strip()

    rows = []
    for path in selected_paths(pieces_dir, piece):
        score = yaml.safe_load(path.read_text()) or {}
        if not isinstance(score, dict):
            raise ValueError(f"{path}: a piece file holds keys such as tempo and voices, not a {type(score).__name__}")
        # the file's name is the piece's name, as a dbt model's would be
        rows.append((path.stem, str(path), json.dumps(score)))

    session.execute(
        """
        create or replace temp table _piece_files (
            piece_id varchar,
            file_path varchar,
            score varchar
        )
        """
    )
    if rows:
        session.executemany("insert into _piece_files values (?, ?, ?)", rows)

    return session.sql("select piece_id, file_path, score::json as score from _piece_files")
