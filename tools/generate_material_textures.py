#!/usr/bin/env python3
"""Generate the small, tileable PBR texture set used by the mobile visual pass."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SIZE = 256
OUT = Path(__file__).resolve().parents[1] / "assets" / "textures" / "premium"


def noise(seed: int, scale: int = 24) -> Image.Image:
    rng = random.Random(seed)
    small = Image.new("L", (scale, scale))
    small.putdata([rng.randrange(256) for _ in range(scale * scale)])
    return small.resize((SIZE, SIZE), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(1.2))


def colorize(height: Image.Image, base: tuple[int, int, int], contrast: float = 0.22) -> Image.Image:
    pixels = []
    for value in height.getdata():
        factor = 1.0 + (value / 255.0 - 0.5) * contrast
        pixels.append(tuple(max(0, min(255, int(channel * factor))) for channel in base) + (255,))
    result = Image.new("RGBA", (SIZE, SIZE))
    result.putdata(pixels)
    return result


def normal_map(height: Image.Image, strength: float = 2.0) -> Image.Image:
    source = height.load()
    result = Image.new("RGB", (SIZE, SIZE))
    target = result.load()
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (source[(x - 1) % SIZE, y] - source[(x + 1) % SIZE, y]) / 255.0
            dy = (source[x, (y - 1) % SIZE] - source[x, (y + 1) % SIZE]) / 255.0
            nx, ny, nz = dx * strength, dy * strength, 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            target[x, y] = (int(127.5 + 127.5 * nx / length), int(127.5 - 127.5 * ny / length), int(127.5 + 127.5 * nz / length))
    return result


def roughness(height: Image.Image, low: int, high: int) -> Image.Image:
    return height.point(lambda value: int(low + (high - low) * value / 255.0))


def add_masonry(height: Image.Image, seed: int, rows: int, mortar: int = 5) -> None:
    draw = ImageDraw.Draw(height)
    rng = random.Random(seed)
    row_height = SIZE // rows
    for row in range(rows):
        y = row * row_height
        draw.rectangle((0, y, SIZE, y + mortar), fill=25)
        width = rng.randint(46, 76)
        offset = -width // 2 if row % 2 else 0
        for x in range(offset, SIZE, width):
            draw.rectangle((x, y, x + mortar, min(SIZE, y + row_height)), fill=32)
    height.paste(height.filter(ImageFilter.GaussianBlur(1.0)))


def add_wood(height: Image.Image, seed: int) -> None:
    draw = ImageDraw.Draw(height)
    rng = random.Random(seed)
    for y in range(12, SIZE, 30):
        draw.line((0, y, SIZE, y + rng.randint(-3, 3)), fill=42, width=3)
    for _ in range(26):
        y = rng.randrange(SIZE)
        amplitude = rng.randrange(2, 8)
        points = [(x, y + int(math.sin(x * 0.045 + rng.random() * 5) * amplitude)) for x in range(0, SIZE + 1, 8)]
        draw.line(points, fill=rng.randrange(75, 130), width=rng.choice((1, 2)))
    for _ in range(7):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        draw.ellipse((x - 7, y - 3, x + 7, y + 3), outline=52, width=2)


def add_shingles(height: Image.Image, seed: int) -> None:
    draw = ImageDraw.Draw(height)
    rng = random.Random(seed)
    for row, y in enumerate(range(0, SIZE, 32)):
        draw.line((0, y, SIZE, y), fill=35, width=4)
        offset = -16 if row % 2 else 0
        for x in range(offset, SIZE, 32):
            draw.line((x, y, x, min(SIZE, y + 32)), fill=55, width=3)
            draw.line((x + 3, y + 27, x + 29, y + 27 + rng.randrange(-2, 3)), fill=95, width=2)


def add_ground(height: Image.Image, seed: int, stones: bool) -> None:
    draw = ImageDraw.Draw(height)
    rng = random.Random(seed)
    for _ in range(90 if stones else 180):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        radius = rng.randrange(1, 5 if stones else 3)
        value = rng.randrange(65, 175)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=value)
    if stones:
        # Broad compressed bands read as cart and foot wear at isometric distance.
        for x in (70, 184):
            draw.rounded_rectangle((x - 15, -8, x + 15, SIZE + 8), radius=12, fill=112)
        for _ in range(18):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            rx, ry = rng.randrange(5, 13), rng.randrange(3, 8)
            draw.ellipse((x - rx, y - ry, x + rx, y + ry), outline=60, width=2)
    else:
        # Directional blade clusters give grass a readable weave without noisy pixels.
        for _ in range(120):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            length = rng.randrange(4, 11)
            draw.line((x, y + length, x + rng.choice((-2, -1, 1, 2)), y), fill=rng.randrange(105, 190), width=1)


def tint_ground(albedo: Image.Image, seed: int, path: bool) -> Image.Image:
    """Add large-scale color variation that survives mipmapping and remains tileable."""
    rng = random.Random(seed)
    overlay = Image.new("RGBA", albedo.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for _ in range(28 if path else 38):
        x, y = rng.randrange(SIZE), rng.randrange(SIZE)
        rx, ry = rng.randrange(12, 38), rng.randrange(8, 30)
        color = (128, 87, 48, 22) if path else rng.choice(((42, 91, 45, 24), (119, 116, 53, 18), (31, 70, 47, 18)))
        # Repeat every mark across neighboring tiles when it overlaps an edge. This
        # avoids visible seams after UV repetition on the broad village ground plane.
        for offset_x in (-SIZE, 0, SIZE):
            for offset_y in (-SIZE, 0, SIZE):
                draw.ellipse((x-rx+offset_x, y-ry+offset_y,
                    x+rx+offset_x, y+ry+offset_y), fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(7))
    return Image.alpha_composite(albedo.convert("RGBA"), overlay)


def build(name: str, base: tuple[int, int, int], seed: int, kind: str, rough: tuple[int, int], strength: float) -> None:
    height = noise(seed)
    if kind == "stone":
        add_masonry(height, seed, 7)
    elif kind == "wood":
        add_wood(height, seed)
    elif kind == "roof":
        add_shingles(height, seed)
    elif kind == "ground":
        add_ground(height, seed, False)
    elif kind == "path":
        add_ground(height, seed, True)
    elif kind == "plaster":
        draw = ImageDraw.Draw(height)
        rng = random.Random(seed)
        for _ in range(20):
            x, y = rng.randrange(SIZE), rng.randrange(SIZE)
            draw.arc((x - 15, y - 9, x + 15, y + 9), 190, 345, fill=rng.randrange(65, 110), width=2)
    albedo = colorize(height, base, 0.25)
    if kind in ("ground", "path"):
        albedo = tint_ground(albedo, seed + 101, kind == "path")
    albedo.save(OUT / f"{name}_albedo.png", optimize=True)
    normal_map(height, strength).save(OUT / f"{name}_normal.png", optimize=True)
    roughness(height, *rough).save(OUT / f"{name}_roughness.png", optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    specs = [
        ("grass", (66, 92, 57), 11, "ground", (205, 250), 1.15),
        ("earth_path", (112, 89, 62), 17, "path", (190, 245), 1.5),
        ("warm_stone", (116, 121, 111), 23, "stone", (185, 240), 1.8),
        ("lime_plaster", (197, 184, 151), 29, "plaster", (210, 250), 1.0),
        ("oak_timber", (105, 70, 42), 31, "wood", (175, 235), 1.8),
        ("slate_roof", (47, 67, 72), 37, "roof", (180, 235), 2.0),
        ("dungeon_wall", (61, 70, 74), 41, "stone", (205, 250), 2.2),
        ("dungeon_floor", (54, 62, 65), 43, "path", (210, 252), 2.0),
        ("aged_iron", (47, 51, 51), 47, "path", (125, 205), 1.65),
    ]
    for spec in specs:
        build(*spec)


if __name__ == "__main__":
    main()
