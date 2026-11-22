"""Create a piece or stored instrument from its template in templates/.

    python scripts/new_model.py piece my_piece
    python scripts/new_model.py instrument my_instrument

Writes models/<kind>s/<name>.yml from templates/<kind>.yml, with __NAME__
replaced and the template's header comment dropped, plus the one-line
<name>.sql. `make new-piece NAME=…` and `make new-instrument NAME=…` call it.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MACROS = {"piece": "compose", "instrument": "instrument"}
VALID_NAME = re.compile(r"^[a-z][a-z0-9_]*$")


def existing_resource(name: str) -> Path | None:
    """The model or seed file already called `name`, if there is one."""
    candidates = [
        *(ROOT / "models").rglob(f"{name}.sql"),
        *(ROOT / "models").rglob(f"{name}.py"),
        *(ROOT / "models").rglob(f"{name}.yml"),
        *(ROOT / "seeds").glob(f"{name}.csv"),
    ]
    return min(candidates, default=None)


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in MACROS or not VALID_NAME.match(argv[2]):
        print(__doc__.strip(), file=sys.stderr)
        print("\nnames are lowercase snake_case, starting with a letter", file=sys.stderr)
        return 1

    kind, name = argv[1], argv[2]
    # dbt names must be unique across models and seeds, whatever their layer
    taken_by = existing_resource(name)
    if taken_by:
        print(f"{taken_by.relative_to(ROOT)} already uses the name {name}", file=sys.stderr)
        return 1

    directory = ROOT / "models" / f"{kind}s"
    yml_path = directory / f"{name}.yml"
    sql_path = directory / f"{name}.sql"

    template = (ROOT / "templates" / f"{kind}.yml").read_text()
    # the template's header explains how to use the template; the new file doesn't need it
    body = template[template.index("models:"):]
    yml_path.write_text(body.replace("__NAME__", name))
    sql_path.write_text(f"{{{{ {MACROS[kind]}() }}}}\n")

    print(f"created {yml_path.relative_to(ROOT)} and {sql_path.relative_to(ROOT)}")
    print("run `make build` to register and render it")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
