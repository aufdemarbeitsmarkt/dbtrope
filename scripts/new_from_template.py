"""Create a piece or stored instrument file from its template in templates/.

    python scripts/new_from_template.py piece my_piece
    python scripts/new_from_template.py instrument my_instrument

Writes pieces/<name>.yml or instruments/<name>.yml from templates/<kind>.yml,
without the template's header comment. `make new-piece NAME=…` and
`make new-instrument NAME=…` call it.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIRECTORIES = {"piece": ROOT / "pieces", "instrument": ROOT / "instruments"}
VALID_NAME = re.compile(r"^[a-z][a-z0-9_]*$")
# the template's header explains how to use the template; the new file starts after it
HEADER_END = "# --- end of template header ---\n"


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[1] not in DIRECTORIES or not VALID_NAME.match(argv[2]):
        print(__doc__.strip(), file=sys.stderr)
        print("\nnames are lowercase snake_case, starting with a letter", file=sys.stderr)
        return 1

    kind, name = argv[1], argv[2]
    path = DIRECTORIES[kind] / f"{name}.yml"
    if path.exists():
        print(f"{path.relative_to(ROOT)} already exists", file=sys.stderr)
        return 1

    template = (ROOT / "templates" / f"{kind}.yml").read_text()
    path.parent.mkdir(exist_ok=True)
    path.write_text(template.split(HEADER_END, 1)[1])

    print(f"created {path.relative_to(ROOT)}")
    if kind == "piece":
        print(f"run `make build PIECE={name}` to render it")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
