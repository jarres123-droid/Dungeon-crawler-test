#!/usr/bin/env python3
"""Generate Greyhaven's first deterministic Blockbench building batch.

The checked-in 5.0 template remains the schema authority.  This script copies
its project-level shape and only populates Blockbench's documented cube and
texture records.  One Blockbench unit is 1/16 metre.
"""

from __future__ import annotations

import json
import math
import struct
import uuid
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "art_source/blockbench/templates/greyhaven_asset_template.bbmodel"
BASE = ROOT / "art_source/blockbench/greyhaven"
U = 16.0
NAMESPACE = uuid.UUID("4bbfef91-2985-4c41-80de-332ddd65f06c")
MATERIALS = ["timber", "plaster", "stone", "roof", "metal", "glass"]


def uid(*parts: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "/".join(parts)))


def png(path: Path, base: tuple[int, int, int], kind: str) -> None:
    """Write a small seamless, hand-painted-style RGBA texture with stdlib."""
    width = height = 64
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            noise = ((x * 17 + y * 29 + (x * y) * 3) % 13) - 6
            if kind == "timber":
                accent = -25 if y % 16 in (0, 1) else (10 if (x + y // 4) % 23 == 0 else 0)
            elif kind == "plaster":
                accent = -12 if (x * 3 + y * 5) % 47 == 0 else 0
            elif kind == "stone":
                accent = -20 if y % 16 == 0 or (x + (y // 16) * 9) % 24 == 0 else 0
            elif kind == "roof":
                accent = -24 if y % 12 in (0, 1) or (x + (y // 12) * 5) % 16 == 0 else 0
            elif kind == "glass":
                accent = 20 if (x - y) % 19 == 0 else 0
            else:
                accent = -10 if (x + y) % 11 == 0 else 0
            row.extend(max(0, min(255, c + noise + accent)) for c in base)
            row.append(255)
        rows.append(bytes(row))
    raw = b"".join(rows)
    chunk = lambda tag, data: struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(data)


def faces(texture: int, uv=(0, 0, 16, 16)) -> dict:
    return {side: {"uv": list(uv), "texture": texture} for side in ("north", "east", "south", "west", "up", "down")}


class Model:
    def __init__(self, name: str):
        self.name = name
        self.elements: list[dict] = []

    def cube(self, name: str, start, end, material: str, *, rotation=None, origin=None, inflate=0.0):
        e = {
            "name": name, "box_uv": False, "render_order": "default", "locked": False,
            "export": True, "scope": 0, "allow_mirror_modeling": True,
            "from": [round(v, 4) for v in start], "to": [round(v, 4) for v in end],
            "autouv": 0, "color": MATERIALS.index(material),
            "origin": [round(v, 4) for v in (origin or (0, 0, 0))],
            "faces": faces(MATERIALS.index(material)), "type": "cube", "uuid": uid(self.name, name),
        }
        if rotation:
            e["rotation"] = [round(v, 4) for v in rotation]
        if inflate:
            e["inflate"] = inflate
        self.elements.append(e)

    def save(self, folder: str):
        template = json.loads(TEMPLATE.read_text())
        template["name"] = self.name
        template["resolution"] = {"width": 64, "height": 64}
        template["elements"] = self.elements
        template["groups"] = []
        template["outliner"] = [e["uuid"] for e in self.elements]
        template["textures"] = [
            {
                "name": f"greyhaven_{mat}.png", "folder": "", "namespace": "",
                "id": str(i), "particle": False, "render_mode": "default",
                "render_sides": "auto", "frame_time": 1, "frame_order_type": "loop",
                "frame_order": "", "frame_interpolate": False, "visible": True,
                "internal": False, "saved": True, "uuid": uid(self.name, "texture", mat),
                "relative_path": f"../../textures/greyhaven_{mat}.png",
                "uv_width": 64, "uv_height": 64,
            } for i, mat in enumerate(MATERIALS)
        ]
        out = BASE / "buildings" / folder / f"{self.name}.bbmodel"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(template, separators=(",", ":")) + "\n")


def foundation(m: Model):
    # Irregular masonry courses create a 0.45 m plinth without changing the 4 m envelope.
    for course, (y0, y1) in enumerate(((0, 3.6), (3.6, 7.2))):
        widths = (15, 18, 14, 17) if course == 0 else (18, 14, 17, 15)
        x = -32
        for i, w in enumerate(widths):
            m.cube(f"foundation_{course}_{i}", (x + .25, y0 + .15, -2.2), (x + w - .25, y1 - .1, 2.2), "stone")
            x += w


def posts(m: Model, include_mid=True):
    for label, x in (("left", -32), ("right", 28)):
        m.cube(f"corner_post_{label}", (x, 7.0, -2.7), (x + 4, 48, 2.7), "timber")
    if include_mid:
        m.cube("center_post", (-2, 7.0, -2.5), (2, 48, 2.5), "timber")
    m.cube("sole_plate", (-32, 6.6, -2.6), (32, 10.0, 2.6), "timber")
    m.cube("top_plate", (-32, 44.2, -2.8), (32, 48, 2.8), "timber")
    # Pegs project just enough to read at isometric distance.
    for i, x in enumerate((-29.5, -1.1, 28.9)):
        for y in (9.0, 45.7):
            m.cube(f"peg_{i}_{int(y)}", (x, y, -3.15), (x + 1.2, y + 1.2, -2.65), "metal")


def plain_wall():
    m = Model("greyhaven_wall_timber_plain_4m")
    foundation(m)
    # Inset plaster panels have real 0.25 m wall thickness behind 0.30 m frames.
    m.cube("plaster_left", (-28, 9.5, -2), (-2, 44.4, 2), "plaster")
    m.cube("plaster_right", (2, 9.5, -2), (28, 44.4, 2), "plaster")
    posts(m)
    for side, x, angle in (("left", -16, -32), ("right", 16, 32)):
        m.cube(f"brace_{side}", (x - 1.7, 12, -2.75), (x + 1.7, 42, 2.75), "timber", rotation=(0, 0, angle), origin=(x, 27, 0))
    # A shallow weather ledge protects the plaster/foundation seam.
    m.cube("drip_ledge", (-30, 9.5, -3.3), (30, 11.0, -2.5), "timber", rotation=(8, 0, 0), origin=(0, 10, -2.5))
    m.save("walls")


def window_wall():
    m = Model("greyhaven_wall_timber_window_4m")
    foundation(m); posts(m)
    # Same shell as the plain wall, split around a 1.25 x 1.35 m aperture.
    m.cube("plaster_left", (-28, 9.5, -2), (-12, 44.4, 2), "plaster")
    m.cube("plaster_right", (12, 9.5, -2), (28, 44.4, 2), "plaster")
    m.cube("plaster_below", (-12, 9.5, -2), (12, 20, 2), "plaster")
    m.cube("plaster_above", (-12, 41.6, -2), (12, 44.4, 2), "plaster")
    for label, bounds in (("left", (-12, 19.2, -2.6, -9, 42.4, 2.6)), ("right", (9, 19.2, -2.6, 12, 42.4, 2.6)), ("sill", (-13, 18.3, -3.5, 13, 21.3, 3.0)), ("lintel", (-13, 40.3, -2.8, 13, 43.3, 2.8))):
        m.cube(f"window_frame_{label}", bounds[:3], bounds[3:], "timber")
    m.cube("glass_left", (-8.7, 22, -2.05), (-.8, 39.8, -1.6), "glass")
    m.cube("glass_right", (.8, 22, -2.05), (8.7, 39.8, -1.6), "glass")
    m.cube("window_mullion", (-.8, 20.5, -2.8), (.8, 41, -1.5), "timber")
    m.cube("window_transom", (-10, 30.0, -2.8), (10, 31.5, -1.5), "timber")
    m.cube("sill_stone", (-14, 17.2, -3.7), (14, 19.0, 3.2), "stone", rotation=(3, 0, 0), origin=(0, 18, 0))
    m.save("walls")


def door_wall():
    m = Model("greyhaven_wall_timber_door_4m")
    foundation(m); posts(m)
    # Foundation is interrupted by the threshold; clear opening is 1.10 x 2.20 m.
    m.elements = [e for e in m.elements if not e["name"].startswith("foundation_")]
    for side, x0, x1 in (("left", -32, -8.8), ("right", 8.8, 32)):
        for course, (y0, y1) in enumerate(((0, 3.6), (3.6, 7.2))):
            m.cube(f"foundation_{side}_{course}", (x0+.25, y0+.15, -2.2), (x1-.25, y1-.1, 2.2), "stone")
        m.cube(f"plaster_{side}", (x0+4, 9.5, -2), (x1, 44.4, 2), "plaster")
    m.cube("plaster_header", (-8.8, 42.4, -2), (8.8, 44.4, 2), "plaster")
    m.cube("door_jamb_left", (-10.8, 6.0, -2.8), (-8.8, 43.5, 2.8), "timber")
    m.cube("door_jamb_right", (8.8, 6.0, -2.8), (10.8, 43.5, 2.8), "timber")
    m.cube("door_lintel", (-12, 41.8, -3.0), (12, 45.0, 3.0), "timber")
    m.cube("oak_door", (-8.5, 7.0, -2.0), (8.5, 41.8, -.7), "timber")
    for i, x in enumerate((-5.5, 0, 5.5)):
        m.cube(f"door_plank_reveal_{i}", (x-.25, 7.5, -2.25), (x+.25, 41.2, -1.9), "timber")
    for i, y in enumerate((13, 34)):
        m.cube(f"iron_strap_{i}", (-8.2, y, -2.5), (6.7, y+1.6, -2.1), "metal")
    m.cube("door_handle", (5.4, 25, -3.0), (6.7, 27, -2.45), "metal")
    m.cube("stone_threshold", (-10, 5.5, -3.5), (10, 7.2, 3.5), "stone")
    m.save("walls")


def roof_slope():
    m = Model("greyhaven_roof_slope_4m")
    pitch = math.degrees(math.atan2(28, 40))
    length = math.hypot(28, 40)
    # Ridge at (z=0,y=76), eave at (z=-40,y=48): 2.5 m run + 1.75 m rise.
    center_y, center_z = 62, -20
    m.cube("roof_deck", (-32, center_y-1.1, center_z-length/2), (32, center_y+1.1, center_z+length/2), "timber", rotation=(-pitch, 0, 0), origin=(0, center_y, center_z))
    # Overlapping shingle bands add silhouette and layered construction.
    for row in range(7):
        z = -37 + row * 6
        y = 50.1 + row * 4.2
        m.cube(f"shingle_course_{row}", (-33, y-1.15, z-4.2), (33, y+1.15, z+4.2), "roof", rotation=(-pitch, 0, 0), origin=(0, y, z))
    for x in (-29, -14.5, 0, 14.5, 29):
        m.cube(f"rafter_{int(x*10)}", (x-1.2, center_y-2.3, center_z-length/2), (x+1.2, center_y-.3, center_z+length/2), "timber", rotation=(-pitch, 0, 0), origin=(x, center_y, center_z))
    m.cube("eave_fascia", (-34, 46.0, -42), (34, 51.2, -38), "timber")
    m.save("roofs")


def roof_ridge():
    m = Model("greyhaven_roof_ridge_4m")
    pitch = math.degrees(math.atan2(28, 40))
    # Four metres along X; origin and ridge center exactly match the slope asset.
    for side, z, angle in (("front", -2.3, -pitch), ("back", 2.3, pitch)):
        m.cube(f"ridge_cap_{side}", (-33, 74.8, z-4.5), (33, 77.2, z+4.5), "roof", rotation=(angle, 0, 0), origin=(0, 76, 0))
    m.cube("ridge_beam", (-32, 72.8, -2.0), (32, 76.0, 2.0), "timber")
    for x in (-30, -15, 0, 15, 30):
        m.cube(f"ridge_joint_{x}", (x-1, 72.0, -2.5), (x+1, 77.5, 2.5), "metal")
    m.save("roofs")


def main():
    texture_dir = BASE / "textures"
    texture_dir.mkdir(parents=True, exist_ok=True)
    palette = {"timber": (91, 55, 34), "plaster": (205, 181, 139), "stone": (111, 108, 100), "roof": (112, 62, 47), "metal": (58, 61, 62), "glass": (77, 123, 133)}
    for name, color in palette.items():
        png(texture_dir / f"greyhaven_{name}.png", color, name)
    plain_wall(); window_wall(); door_wall(); roof_slope(); roof_ridge()


if __name__ == "__main__":
    main()
