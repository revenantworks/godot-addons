"""Turns the frames from capture_gif.gd into the store GIF.

Run from the project folder, after capture_gif.gd:
    py tools/make_gif.py
Reads tools/out/gif/frame_*.png, writes media/crossfade.gif (one shared palette, looping).
Needs Pillow (py -m pip install pillow).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

FRAME_MS = 80  # 12.5 frames a second, to keep the file near 2.5 MB


def main(argv: list[str] | None = None) -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--frames", type=Path, default=here / "out" / "gif")
    ap.add_argument("--out", type=Path, default=here.parent / "media" / "crossfade.gif")
    ap.add_argument("--width", type=int, default=480, help="output width in pixels")
    ap.add_argument("--colors", type=int, default=64, help="palette size, 2 to 256")
    args = ap.parse_args(argv)
    try:
        from PIL import Image
    except ImportError:
        print("make_gif: Pillow is missing: py -m pip install pillow", file=sys.stderr)
        return 2
    paths = sorted(args.frames.glob("frame_*.png"))
    if not paths:
        print(f"make_gif: no frames in {args.frames}; run capture_gif.gd first", file=sys.stderr)
        return 1
    frames = []
    for p in paths:
        im = Image.open(p).convert("RGB")
        if im.width != args.width:
            h = round(im.height * args.width / im.width)
            im = im.resize((args.width, h), Image.LANCZOS)
        frames.append(im)
    # One palette from a strip of frames across the loop, so colours do not flicker.
    strip = Image.new("RGB", (frames[0].width, frames[0].height * 4))
    for n, i in enumerate(range(0, len(frames), max(1, len(frames) // 4))):
        if n < 4:
            strip.paste(frames[i], (0, frames[0].height * n))
    palette = strip.quantize(colors=max(2, min(256, args.colors)), method=Image.Quantize.MEDIANCUT)
    out = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out[0].save(args.out, save_all=True, append_images=out[1:], duration=FRAME_MS, loop=0, optimize=True)
    print(f"make_gif: {len(out)} frames, {args.out.stat().st_size // 1024} KiB, {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
