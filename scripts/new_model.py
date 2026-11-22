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


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in MACROS or not VALID_NAME.match(argv[2]):
        print(__doc__.strip(), file=sys.stderr)
        print("\nnames are lowercase snake_case, starting with a letter", file=sys.stderr)
        return 1

    kind, name = argv[1], argv[2]
    directory = ROOT / "models" / f"{kind}s"
    yml_path = directory / f"{name}.yml"
    sql_path = directory / f"{name}.sql"
    existing = [p for p in (yml_path, sql_path) if p.exists()]
    if existing:
        print(f"{existing[0].relative_to(ROOT)} already exists", file=sys.stderr)
        return 1

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
