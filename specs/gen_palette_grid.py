#!/usr/bin/env python3
"""Generate HELM palette grid — 20 nautical palettes, 4x5, proper dark/light split."""
from PIL import Image, ImageDraw, ImageFont
import os

PALETTES = [
    # Open Water
    ("Ocean Breeze",  "#0EA5E9", "#06B6D4", "#F0F9FF"),
    ("Deep Navy",     "#1E3A5F", "#3B82F6", "#93C5FD"),
    ("Tide Pool",     "#0F766E", "#14B8A6", "#CCFBF1"),
    ("Northern Star", "#1E40AF", "#60A5FA", "#FCD34D"),
    # Warm & Coastal
    ("Coral Reef",    "#EA580C", "#FB923C", "#0EA5E9"),
    ("Lighthouse",    "#DC2626", "#F97316", "#1E3A5F"),
    ("Horizon Gold",  "#D97706", "#F59E0B", "#0F172A"),
    ("Sandy Shore",   "#D2A679", "#B45309", "#164E63"),
    # Deep & Dramatic
    ("Midnight Helm", "#1E1B4B", "#7C3AED", "#C084FC"),
    ("Harbor Watch",  "#1F2937", "#4B5563", "#10B981"),
    ("Storm Front",   "#374151", "#6B7280", "#7C3AED"),
    ("Abyss",         "#0C0A09", "#1C1917", "#3B82F6"),
    # Fresh & Natural
    ("Kelp Forest",   "#166534", "#4ADE80", "#CA8A04"),
    ("Tidal Marsh",   "#4D7C0F", "#84CC16", "#0F766E"),
    ("Moss & Violet", "#4A7C59", "#7C3AED", "#D97706"),  # #15 = {{USER_JERRY}}'s current
    ("Seafoam",       "#047857", "#34D399", "#6EE7B7"),
    # Classic & Clean
    ("Sailcloth",     "#292524", "#78716C", "#E7E5E4"),
    ("Fog Light",     "#374151", "#9CA3AF", "#F3F4F6"),
    ("Compass Rose",  "#9F1239", "#BE185D", "#F0ABFC"),
    ("Nautical Gold", "#1E3A5F", "#B45309", "#F5F5F4"),
]

CURRENT_IDX = 14   # 0-indexed: Moss & Violet
COLS = 4
ROWS = 5

# Fonts — load with fallback
def load_font(size, bold=False):
    paths = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()

FONT_TITLE = load_font(36, bold=True)
FONT_NAME  = load_font(36, bold=True)   # 50% bigger than old 24
FONT_NUM   = load_font(28)              # 50% bigger than old 20

CARD_W   = 420
HEADER_H = 80     # taller header for 36pt name
SWATCH_H = 100    # taller swatches (freed space from removed hex labels)
PADDING  = 20     # internal vertical padding inside card body
CARD_H   = HEADER_H + SWATCH_H + PADDING

DARK_BG   = "#111827"
LIGHT_BG  = "#F0F4F8"
HEADER_BG = "#1E2433"
BORDER    = "#2D3748"
IMG_PAD   = 12
TITLE_H   = 64

IMG_W = COLS * CARD_W + (COLS + 1) * IMG_PAD
IMG_H = ROWS * CARD_H + (ROWS + 1) * IMG_PAD + TITLE_H

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

img = Image.new("RGB", (IMG_W, IMG_H), "#0F172A")
draw = ImageDraw.Draw(img)

# Title
draw.text((IMG_W // 2, TITLE_H // 2), "HELM  Color Palettes",
          fill="#F9FAFB", font=FONT_TITLE, anchor="mm")

SWATCH_GAP    = 10
SWATCH_MARGIN = 12

def draw_card(x, y, idx, name, p, a1, a2, current):
    # header
    draw.rectangle([x, y, x + CARD_W, y + CARD_H], fill=HEADER_BG)
    draw.rectangle([x, y, x + CARD_W, y + HEADER_H], fill=HEADER_BG)

    txt_color = "#FFFFFF"
    star = " ★" if current else ""
    draw.text((x + 14, y + HEADER_H // 2), f"#{idx + 1}",
              fill="#9CA3AF", font=FONT_NUM, anchor="lm")
    draw.text((x + CARD_W // 2, y + HEADER_H // 2), f"{name}{star}",
              fill=txt_color, font=FONT_NAME, anchor="mm")

    # body halves — dark left, light right
    body_y = y + HEADER_H
    half   = CARD_W // 2

    draw.rectangle([x,        body_y, x + half,   y + CARD_H], fill=DARK_BG)
    draw.rectangle([x + half, body_y, x + CARD_W, y + CARD_H], fill=LIGHT_BG)
    draw.line([x + half, body_y, x + half, y + CARD_H], fill=BORDER, width=2)

    # swatches — centered vertically in body area
    body_inner = SWATCH_H + PADDING
    sw_y = body_y + (body_inner - SWATCH_H) // 2

    colors    = [p, a1, a2]
    sw_total  = half - SWATCH_MARGIN * 2 - SWATCH_GAP * 2
    sw        = sw_total // 3

    for side in range(2):
        side_x = x + side * half
        for i, c in enumerate(colors):
            cx = side_x + SWATCH_MARGIN + i * (sw + SWATCH_GAP)
            draw.rounded_rectangle([cx, sw_y, cx + sw, sw_y + SWATCH_H], radius=8, fill=c)

    # card border
    draw.rectangle([x, y, x + CARD_W - 1, y + CARD_H - 1], outline=BORDER, width=1)


for i, (name, p, a1, a2) in enumerate(PALETTES):
    row = i // COLS
    col = i % COLS
    cx  = IMG_PAD + col * (CARD_W + IMG_PAD)
    cy  = TITLE_H + IMG_PAD + row * (CARD_H + IMG_PAD)
    draw_card(cx, cy, i, name, p, a1, a2, i == CURRENT_IDX)

out = os.path.join(os.path.dirname(__file__), "helm-palettes.png")
img.save(out, "PNG")
print(f"Saved: {out}  ({IMG_W}x{IMG_H})")
