import json
from pathlib import Path

import yaml


def model(dbt, session):
    dbt.config(materialized="table")
    instruments_dir = Path(dbt.config.get("instruments_dir"))

    rows = []
    for path in sorted(instruments_dir.glob("*.yml")):
        definition = yaml.safe_load(path.read_text()) or {}
        if not isinstance(definition, dict):
            raise ValueError(f"{path}: an instrument file holds keys such as partials and adsr, not a {type(definition).__name__}")
        # the file's name is the name pieces use for the instrument
        rows.append((path.stem, str(path), json.dumps(definition)))

    session.execute(
        """
        create or replace temp table _instrument_files (
            instrument_name varchar,
            file_path varchar,
            definition varchar
        )
        """
    )
    if rows:
        session.executemany("insert into _instrument_files values (?, ?, ?)", rows)

    return session.sql(
        "select instrument_name, file_path, definition::json as definition from _instrument_files"
    )
