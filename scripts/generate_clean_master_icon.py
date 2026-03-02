#!/usr/bin/env python3
from PIL import Image, ImageFilter
import numpy as np
import sys

if len(sys.argv) < 3:
    print("Usage: generate_clean_master_icon.py <src_image> <out_png>")
    sys.exit(1)

src_path = sys.argv[1]
out_path = sys.argv[2]

img = Image.open(src_path).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
arr = np.array(img).astype(np.int16)

# Focus on the symbol zone to keep the original wave design intact.
# Tuned for current source where symbol sits inside a rounded white tile.
crop = arr[300:700, 220:820]

# Remove near-white/gray backdrop; keep colored wave/line pixels.
# This preserves the original motif while dropping white card edges and glow.
maxc = crop.max(axis=2)
minc = crop.min(axis=2)
sat = (maxc - minc) / np.maximum(maxc, 1)

# Keep moderately saturated or darker pixels (the motif strokes/shapes).
mask = (sat > 0.09) | (maxc < 205)

ys, xs = np.where(mask)
if len(xs) == 0:
    raise RuntimeError("Could not detect logo motif pixels")

x0, x1 = xs.min(), xs.max()
y0, y1 = ys.min(), ys.max()
motif = crop[y0:y1+1, x0:x1+1]
mask2 = mask[y0:y1+1, x0:x1+1]

# Slightly feather edges for cleaner anti-aliasing.
alpha = (mask2.astype(np.float32) * 255.0).astype(np.uint8)
alpha_img = Image.fromarray(alpha, mode="L")
alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=0.6))

motif_img = Image.fromarray(motif.astype(np.uint8), mode="RGB").convert("RGBA")
motif_img.putalpha(alpha_img)

# Compose full-bleed icon background (no pre-rounded card).
bg = Image.new("RGB", (1024, 1024), (244, 241, 234))  # #F4F1EA
canvas = bg.convert("RGBA")

# Scale motif to modern icon proportion.
target_w = 620
scale = target_w / motif_img.width
new_size = (int(motif_img.width * scale), int(motif_img.height * scale))
motif_img = motif_img.resize(new_size, Image.Resampling.LANCZOS)

x = (1024 - motif_img.width) // 2
y = (1024 - motif_img.height) // 2 + 8
canvas.alpha_composite(motif_img, (x, y))

canvas.convert("RGB").save(out_path, format="PNG")
print(f"Wrote {out_path}")
