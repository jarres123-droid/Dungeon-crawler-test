#!/usr/bin/env python3
"""Validate Greyhaven bbmodels against the repository's authoritative template."""

import json
import base64
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = json.loads((ROOT / "art_source/blockbench/templates/greyhaven_asset_template.bbmodel").read_text())
FILES = sorted((ROOT / "art_source/blockbench/greyhaven/buildings").glob("**/*.bbmodel"))
EXPECTED = {
    "greyhaven_wall_timber_plain_4m.bbmodel", "greyhaven_wall_timber_window_4m.bbmodel",
    "greyhaven_wall_timber_door_4m.bbmodel", "greyhaven_roof_slope_4m.bbmodel",
    "greyhaven_roof_ridge_4m.bbmodel",
}

errors = []
seen_ids = {}
if {p.name for p in FILES} != EXPECTED:
    errors.append("asset set does not match the five-file first batch")
for path in FILES:
    try:
        model = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        errors.append(f"{path}: invalid JSON: {exc}")
        continue
    if model.get("meta") != TEMPLATE["meta"]:
        errors.append(f"{path}: meta/version differs from template")
    if set(model) != set(TEMPLATE):
        errors.append(f"{path}: root structure differs from template")
    elements = model.get("elements", [])
    signatures = []
    element_ids = [e.get("uuid") for e in elements]
    texture_ids = [t.get("uuid") for t in model.get("textures", [])]
    all_ids = element_ids + texture_ids
    if None in all_ids or len(all_ids) != len(set(all_ids)):
        errors.append(f"{path}: missing or duplicate UUID")
    for item_id in all_ids:
        if item_id in seen_ids:
            errors.append(f"{path}: UUID also used by {seen_ids[item_id]}")
        seen_ids[item_id] = path
    if model.get("outliner") != element_ids:
        errors.append(f"{path}: malformed outliner references")
    for element in elements:
        if element.get("type") != "cube":
            errors.append(f"{path}: unsupported/fragile element type {element.get('type')}")
            continue
        start, end = element.get("from", []), element.get("to", [])
        if len(start) != 3 or len(end) != 3 or any(a >= b for a, b in zip(start, end)):
            errors.append(f"{path}: zero or negative cube dimensions in {element.get('name')}")
        signature = (tuple(start), tuple(end), tuple(element.get("rotation", (0, 0, 0))), tuple(element.get("origin", (0, 0, 0))))
        if signature in signatures:
            errors.append(f"{path}: duplicate element volume/transform in {element.get('name')}")
        signatures.append(signature)
        expected_faces = {"north", "east", "south", "west", "up", "down"}
        if set(element.get("faces", {})) != expected_faces:
            errors.append(f"{path}: incomplete faces in {element.get('name')}")
        for face in element.get("faces", {}).values():
            texture = face.get("texture")
            if not isinstance(texture, int) or not 0 <= texture < len(texture_ids):
                errors.append(f"{path}: malformed face texture reference")
                break
    for texture in model.get("textures", []):
        target = (path.parent / texture.get("relative_path", "")).resolve()
        if not target.is_file():
            errors.append(f"{path}: missing texture {target}")
        source = texture.get("source", "")
        try:
            header, encoded = source.split(",", 1)
            if header != "data:image/png;base64" or base64.b64decode(encoded) != target.read_bytes():
                raise ValueError
        except (ValueError, OSError):
            errors.append(f"{path}: missing or stale embedded texture {texture.get('name')}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f"Validated {len(FILES)} Blockbench 5.0 assets; JSON, UUIDs, outliner, and texture references are sound.")
