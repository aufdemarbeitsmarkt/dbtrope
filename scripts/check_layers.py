"""Check dbtrope's layer rules against a compiled dbt manifest.

Run after `dbt parse` (or any dbt command that writes target/manifest.json):

    python scripts/check_layers.py [path/to/manifest.json]

Rules:
  - a model's layer is the first directory under models/
  - each layer may only ref() the layers listed in ALLOWED_UPSTREAM
  - models in intermediate/ are named int_{topic}__{transformation}
  - no model outside intermediate/ uses the int_ prefix, and no model uses stg_
  - every model has a description
  - models in base/, intermediate/ and render/ are documented in their
    directory's _<directory>.yml (pieces and instruments keep one .yml each,
    because that file holds the music or the sound)
"""

import json
import re
import sys
from pathlib import Path

ALLOWED_UPSTREAM = {
    # a piece's depends_on lines point at the stored instruments it uses
    "pieces": {"instruments", "seed"},
    "instruments": {"seed"},
    "base": {"pieces", "instruments", "base", "seed"},
    "intermediate": {"base", "intermediate", "seed"},
    "render": {"intermediate", "render"},
}

# Layers whose models are documented together in models/<layer>/_<layer>.yml.
DIRECTORY_YML_LAYERS = {"base", "intermediate", "render"}

INTERMEDIATE_NAME = re.compile(r"^int_[a-z0-9]+(_[a-z0-9]+)*__[a-z0-9]+(_[a-z0-9]+)*$")


def layer_of(node: dict) -> str:
    if node["resource_type"] == "seed":
        return "seed"
    parts = Path(node["original_file_path"]).parts
    # original_file_path looks like models/<layer>/.../<name>.sql
    return parts[1] if len(parts) > 2 and parts[0] == "models" else "<root>"


def check(manifest: dict) -> list[str]:
    nodes = manifest["nodes"]
    project = manifest["metadata"].get("project_name", "dbtrope")
    errors = []

    for unique_id, node in sorted(nodes.items()):
        if node["resource_type"] != "model" or node["package_name"] != project:
            continue

        name = node["name"]
        layer = layer_of(node)

        if layer not in ALLOWED_UPSTREAM:
            errors.append(
                f"{name}: {node['original_file_path']} is not in a known layer "
                f"({', '.join(sorted(ALLOWED_UPSTREAM))})"
            )
            continue

        if name.startswith("stg_"):
            errors.append(f"{name}: the stg_ prefix is not used; name the model for what it holds")
        if layer == "intermediate" and not INTERMEDIATE_NAME.match(name):
            errors.append(f"{name}: intermediate models are named int_{{topic}}__{{transformation}}")
        if layer != "intermediate" and name.startswith("int_"):
            errors.append(f"{name}: only models in intermediate/ use the int_ prefix")

        if not (node.get("description") or "").strip():
            errors.append(f"{name}: add a description: stating the model's grain")
        if layer in DIRECTORY_YML_LAYERS:
            directory = Path(node["original_file_path"]).parent
            expected = f"{directory.as_posix()}/_{directory.name}.yml"
            documented_in = (node.get("patch_path") or "").split("://", 1)[-1]
            if documented_in != expected:
                errors.append(f"{name}: document it in {expected}, not {documented_in or 'nowhere'}")

        for upstream_id in node["depends_on"]["nodes"]:
            upstream = nodes.get(upstream_id)
            if upstream is None or upstream["package_name"] != project:
                continue
            upstream_layer = layer_of(upstream)
            if upstream_layer not in ALLOWED_UPSTREAM[layer]:
                errors.append(
                    f"{name} ({layer}) reads {upstream['name']} ({upstream_layer}); "
                    f"{layer} may only read: {', '.join(sorted(ALLOWED_UPSTREAM[layer]))}"
                )

    return errors


def main() -> int:
    manifest_path = Path(sys.argv[1] if len(sys.argv) > 1 else "target/manifest.json")
    if not manifest_path.exists():
        print(f"{manifest_path} not found; run `dbt parse` first", file=sys.stderr)
        return 2

    errors = check(json.loads(manifest_path.read_text()))
    for error in errors:
        print(f"layer check: {error}", file=sys.stderr)
    if errors:
        return 1
    print("layer check: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
