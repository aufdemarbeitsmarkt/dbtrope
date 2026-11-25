import json
from pathlib import Path

import yaml


def model(dbt, session):
    dbt.config(materialized="table")
    effects_dir = Path(dbt.config.get("effects_dir"))

    rows = []
    for path in sorted(effects_dir.glob("*.yml")):
        definition = yaml.safe_load(path.read_text()) or {}
        if not isinstance(definition, dict):
            raise ValueError(f"{path}: an effect file holds one effect, such as reverb with its settings, not a {type(definition).__name__}")
        # the file's name is the name instruments use in use:
        rows.append((path.stem, str(path), json.dumps(definition)))

    session.execute(
        """
        create or replace temp table _effect_files (
            named_effect varchar,
            file_path varchar,
            definition varchar
        )
        """
    )
    if rows:
        session.executemany("insert into _effect_files values (?, ?, ?)", rows)

    return session.sql(
        "select named_effect, file_path, definition::json as definition from _effect_files"
    )
