"""Script to generate the Podcast Assistant macOS app icon set.

The script renders a 1024x1024 master illustration for the icon and then
scales it to each size required by the asset catalog. The illustration uses a
layered gradient, glow accents, and a stylized microphone with signal bars to
reflect the app's podcast production focus.
"""

from __future__ import annotations

import json
import math
import random
import argparse
from pathlib import Path
from typing import Tuple

from PIL import Image, ImageDraw, ImageFilter

ROOT_DIR = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT_DIR / "PodcastAssistant" / "Assets.xcassets" / "AppIcon.appiconset"
CONTENTS_PATH = ASSET_DIR / "Contents.json"

Color = Tuple[int, int, int]


def _lerp_channel(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def _lerp_color(a: Color, b: Color, t: float) -> Color:
    return tuple(_lerp_channel(ca, cb, t) for ca, cb in zip(a, b))  # type: ignore[return-value]


def _draw_vertical_gradient(image: Image.Image, top: Color, bottom: Color) -> None:
    draw = ImageDraw.Draw(image)
    width, height = image.size
    for y in range(height):
        t = y / max(height - 1, 1)
        draw.line([(0, y), (width, y)], fill=_lerp_color(top, bottom, t))


def _add_noise_overlay(size: int, intensity: float = 0.08) -> Image.Image:
    noise = Image.effect_noise((size, size), 100)
    noise = noise.point(lambda value: int(value * intensity))
    return Image.merge("RGBA", (noise, noise, noise, noise))


def _draw_microphone(draw: ImageDraw.ImageDraw, size: int) -> None:
    center_x = size / 2
    center_y = size * 0.5
    mic_width = size * 0.26
    mic_height = size * 0.36
    corner_radius = size * 0.08

    upper_rect = [
        center_x - mic_width / 2,
        center_y - mic_height / 2,
        center_x + mic_width / 2,
        center_y + mic_height / 2,
    ]
    draw.rounded_rectangle(upper_rect, radius=corner_radius, fill=(246, 248, 255, 255))

    stem_height = size * 0.16
    stem_width = size * 0.1
    stem_rect = [
        center_x - stem_width / 2,
        center_y + mic_height / 2,
        center_x + stem_width / 2,
        center_y + mic_height / 2 + stem_height,
    ]
    draw.rounded_rectangle(stem_rect, radius=stem_width / 2, fill=(224, 228, 255, 255))

    base_radius = size * 0.17
    base_rect = [
        center_x - base_radius,
        center_y + mic_height / 2 + stem_height - size * 0.02,
        center_x + base_radius,
        center_y + mic_height / 2 + stem_height + size * 0.1,
    ]
    draw.ellipse(base_rect, fill=(86, 102, 238, 245))

    shine_height = mic_height * 0.5
    shine_rect = [
        center_x - mic_width * 0.24,
        center_y - shine_height / 2,
        center_x - mic_width * 0.05,
        center_y + shine_height / 2,
    ]
    draw.rounded_rectangle(shine_rect, radius=size * 0.04, fill=(255, 255, 255, 96))


def _draw_signal_bars(draw: ImageDraw.ImageDraw, size: int) -> None:
    center_x = size / 2
    base_y = size * 0.38
    bar_width = size * 0.045
    spacing = bar_width * 0.7
    heights = [0.5, 0.75, 1.0, 0.75, 0.5]
    for index, height_factor in enumerate(heights):
        offset = index - (len(heights) - 1) / 2
        x0 = center_x + offset * (bar_width + spacing) - bar_width / 2
        x1 = x0 + bar_width
        y0 = base_y - size * 0.18 * height_factor
        y1 = base_y + size * 0.18 * height_factor
        draw.rounded_rectangle([x0, y0, x1, y1], radius=bar_width / 2, fill=(255, 255, 255, 200))


def _draw_signal_orbit(draw: ImageDraw.ImageDraw, size: int) -> None:
    center = size / 2
    orbit_colors = [(170, 192, 255, 190), (126, 148, 255, 170), (86, 106, 242, 150)]
    for index, color in enumerate(orbit_colors):
        padding = size * (0.2 + index * 0.08)
        bbox = [padding, padding, size - padding, size - padding]
        draw.arc(bbox, start=210, end=330, fill=color, width=max(1, int(size * 0.015)))
        draw.arc(bbox, start=30, end=150, fill=color, width=max(1, int(size * 0.015)))


def _sprinkle_stars(draw: ImageDraw.ImageDraw, size: int) -> None:
    random.seed(42)
    count = max(6, int(size * 0.04))
    for _ in range(count):
        radius = random.uniform(size * 0.004, size * 0.012)
        x = random.uniform(radius, size - radius)
        y = random.uniform(radius, size * 0.6)
        opacity = random.randint(60, 140)
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(255, 255, 255, opacity))


def render_icon(size: int, variant: str = "normal") -> Image.Image:
    base_color = (26, 32, 88, 255) if variant == "normal" else (0, 0, 0, 0)
    base = Image.new("RGBA", (size, size), base_color)

    if variant == "normal":
        _draw_vertical_gradient(base, (134, 102, 255), (35, 43, 96))

    glow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    glow_radius = size * 0.82
    glow_center = (size / 2, size * 0.38)
    glow_bbox = [
        glow_center[0] - glow_radius / 2,
        glow_center[1] - glow_radius / 2,
        glow_center[0] + glow_radius / 2,
        glow_center[1] + glow_radius / 2,
    ]
    glow_alpha = 90 if variant == "normal" else 140
    glow_draw.ellipse(glow_bbox, fill=(178, 186, 255, glow_alpha))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=size * 0.09))
    base = Image.alpha_composite(base, glow_layer)

    if variant == "normal":
        planet_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        planet_draw = ImageDraw.Draw(planet_layer)
        planet_margin = size * 0.15
        planet_draw.ellipse(
            [planet_margin, planet_margin * 0.92, size - planet_margin, size - planet_margin * 0.7],
            fill=(60, 74, 170, 210),
        )
        planet_draw.ellipse(
            [planet_margin * 1.1, planet_margin, size - planet_margin * 1.1, size - planet_margin * 0.76],
            outline=(220, 230, 255, 150),
            width=max(1, int(size * 0.018)),
        )
        base = Image.alpha_composite(base, planet_layer)

    orbit_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    orbit_draw = ImageDraw.Draw(orbit_layer)
    _draw_signal_orbit(orbit_draw, size)
    base = Image.alpha_composite(base, orbit_layer)

    signal_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    signal_draw = ImageDraw.Draw(signal_layer)
    _draw_signal_bars(signal_draw, size)
    _draw_microphone(signal_draw, size)
    base = Image.alpha_composite(base, signal_layer)

    sparkle_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle_layer)
    _sprinkle_stars(sparkle_draw, size)
    sparkle_layer = sparkle_layer.filter(ImageFilter.GaussianBlur(radius=size * 0.01))
    base = Image.alpha_composite(base, sparkle_layer)

    if variant == "normal":
        noise = _add_noise_overlay(size, intensity=0.06)
        base = Image.alpha_composite(base, noise)

        vignette = Image.new("L", (size, size), 0)
        vignette_draw = ImageDraw.Draw(vignette)
        vignette_draw.ellipse([-size * 0.1, -size * 0.1, size * 1.1, size * 1.1], fill=255)
        vignette = vignette.filter(ImageFilter.GaussianBlur(radius=size * 0.12))
        vignette_layer = Image.merge("RGBA", (
            Image.new("L", (size, size), 0),
            Image.new("L", (size, size), 0),
            Image.new("L", (size, size), 0),
            vignette,
        ))
        base = Image.composite(base, Image.new("RGBA", (size, size), (0, 0, 0, 255)), vignette_layer)

    return base.convert("RGBA")


def generate_icons(variant: str) -> None:
    with open(CONTENTS_PATH, "r", encoding="utf-8") as handle:
        contents = json.load(handle)

    output_dir = ASSET_DIR if variant == "normal" else ROOT_DIR / "docs" / "AppIconTransparent"
    output_dir.mkdir(parents=True, exist_ok=True)

    processed_sizes: set[int] = set()

    for image_entry in contents.get("images", []):
        size_token = image_entry.get("size", "0x0").split("x")[0]
        try:
            point_size = float(size_token)
        except ValueError:
            point_size = 0.0
        scale = image_entry.get("scale", "1x").replace("x", "")
        try:
            scale_factor = int(scale)
        except ValueError:
            scale_factor = 1
        pixel_size = int(round(point_size * scale_factor))
        pixel_size = max(1, pixel_size)

        if variant == "transparent" and pixel_size in processed_sizes:
            continue
        processed_sizes.add(pixel_size)

        if variant == "normal":
            filename = f"appicon-{pixel_size}.png"
            image_entry["filename"] = filename
        else:
            filename = f"appicon-transparent-{pixel_size}.png"

        icon_image = render_icon(pixel_size, variant=variant)
        target_path = output_dir / filename
        icon_image.save(target_path, format="PNG")
        print(f"Saved {filename} ({pixel_size}px) -> {target_path.relative_to(ROOT_DIR)}")

    if variant == "normal":
        with open(CONTENTS_PATH, "w", encoding="utf-8") as handle:
            json.dump(contents, handle, indent=2)
            handle.write("\n")
        print("Updated asset catalog metadata.")
    else:
        print(f"Transparent icons available in {output_dir.relative_to(ROOT_DIR)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Podcast Assistant app icon assets.")
    parser.add_argument(
        "--variant",
        choices=("normal", "transparent"),
        default="normal",
        help="normal: writes into the Xcode asset catalog; transparent: writes PNGs to docs/AppIconTransparent",
    )
    args = parser.parse_args()

    if args.variant == "normal":
        ASSET_DIR.mkdir(parents=True, exist_ok=True)

    generate_icons(args.variant)
