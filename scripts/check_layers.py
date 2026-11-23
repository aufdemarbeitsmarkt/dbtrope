"""Check dbtrope's layer rules against a compiled dbt manifest.

Run after `dbt parse` (or any dbt command that writes target/manifest.json):

    python scripts/check_layers.py [path/to/manifest.json]

Rules:
  - a model's layer is the first directory under models/
  - each layer may only ref() the layers listed in ALLOWED_UPSTREAM
  - models in intermediate/ are named int_{topic}__{transformation}
  - no model outside intermediate/ uses the int_ prefix, and no model uses stg_
  - every model, seed, analysis, singular data test and macro (generic tests
    included) has a description, written in its directory's _<directory>.yml
"""

import json
import re
import sys
from pathlib import Path

ALLOWED_UPSTREAM = {
    "base": {"base", "seed"},
    "intermediate": {"base", "intermediate", "seed"},
    "render": {"intermediate", "render"},
}

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

    errors.extend(check_documentation(manifest))
    return errors


def is_documented_resource(resource: dict) -> bool:
    if resource["resource_type"] in ("model", "seed", "analysis", "macro"):
        return True
    # singular data tests are .sql files; generic tests are generated from YAML
    return resource["resource_type"] == "test" and not resource.get("test_metadata")


def check_documentation(manifest: dict) -> list[str]:
    project = manifest["metadata"].get("project_name", "dbtrope")
    errors = []
    resources = list(manifest["nodes"].values()) + list(manifest["macros"].values())
    for resource in sorted(resources, key=lambda r: r["original_file_path"]):
        if resource["package_name"] != project or not is_documented_resource(resource):
            continue
        name = resource["name"]
        kind = resource["resource_type"]
        if not (resource.get("description") or "").strip():
            what = "stating its grain" if kind == "model" else "saying what it does"
            errors.append(f"{name}: add a description: {what}")
        directory = Path(resource["original_file_path"]).parent
        expected = f"{directory.as_posix()}/_{directory.name}.yml"
        documented_in = (resource.get("patch_path") or "").split("://", 1)[-1]
        if documented_in != expected:
            errors.append(f"{name}: document it in {expected}, not {documented_in or 'nowhere'}")
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
