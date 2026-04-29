#!/usr/bin/env python3
"""
Konwerter Tibia.spr (64x64 native) -> Tibia.cwm dla OTClient.

Czyta sprite'y z natywnego .spr 64x64 (po wczesniejszej migracji spr_to_64.py),
koduje kazdy jako PNG i pakuje do .cwm rozpoznawanego przez OTClient
(zob. src/client/spritemanager.cpp).

Wymaga:  pip install pillow

Uzycie:
    python tools/spr_to_cwm.py data/things/1098/Tibia.spr data/things/1098/Tibia.cwm
"""

import argparse
import io
import struct
from pathlib import Path
from PIL import Image

# Format dla protokolu 1098 (modules/game_features/features.lua):
#   GameSpritesU32          = TAK  (count + offsety jako U32, wlaczane od >= 960)
#   GameSpritesAlphaChannel = NIE  (sprite'y RGB; transparency przez RLE 'transparent runs')
HAS_U32_COUNT = True
HAS_ALPHA = False

SPRITE_SIZE = 64


def decode_spr(spr_path: Path) -> dict[int, bytes]:
    """Czyta Tibia.spr (SPRITE_SIZE x SPRITE_SIZE) i zwraca {sprite_id: bytes(N*N*4) RGBA}."""
    data = spr_path.read_bytes()

    # Header: U32 signature, U32/U16 count
    struct.unpack_from("<I", data, 0)  # signature (nieuzywane przy konwersji do .cwm)
    pos = 4
    if HAS_U32_COUNT:
        count = struct.unpack_from("<I", data, pos)[0]; pos += 4
    else:
        count = struct.unpack_from("<H", data, pos)[0]; pos += 2

    offsets = struct.unpack_from(f"<{count}I", data, pos)

    sprites: dict[int, bytes] = {}
    pixel_count = SPRITE_SIZE * SPRITE_SIZE

    for sprite_id, off in enumerate(offsets, start=1):
        if off == 0:
            continue  # pusty slot — pomijamy (.cwm tez go nie zawiera)

        p = off + 3  # pomijamy 3 bajty color key
        pixel_data_size = struct.unpack_from("<H", data, p)[0]; p += 2
        end = p + pixel_data_size

        pixels = bytearray(pixel_count * 4)
        write_idx = 0  # licznik pikseli (nie bajtow)

        while p < end and write_idx < pixel_count:
            transparent = struct.unpack_from("<H", data, p)[0]; p += 2
            colored     = struct.unpack_from("<H", data, p)[0]; p += 2

            # 'transparent' pikseli — bufor jest juz zerowy, tylko przesuwamy indeks
            write_idx = min(write_idx + transparent, pixel_count)

            # 'colored' pikseli — RGB (+ ewentualnie A)
            for _ in range(colored):
                if write_idx >= pixel_count:
                    break
                bi = write_idx * 4
                pixels[bi]     = data[p]; p += 1
                pixels[bi + 1] = data[p]; p += 1
                pixels[bi + 2] = data[p]; p += 1
                if HAS_ALPHA:
                    pixels[bi + 3] = data[p]; p += 1
                else:
                    pixels[bi + 3] = 0xFF
                write_idx += 1

        sprites[sprite_id] = bytes(pixels)

    return sprites


def encode_png(rgba: bytes) -> bytes:
    img = Image.frombytes("RGBA", (SPRITE_SIZE, SPRITE_SIZE), rgba)
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def encode_cwm(sprites_png: dict[int, bytes], cwm_path: Path) -> None:
    """
    Format .cwm (z spritemanager.cpp:111-134 + filestream.cpp:330):
      U8  version = 0x01
      U32 spritesCount   (najwyzszy sprite_id) -- patrz uwaga ponizej
      U32 entries        (liczba zapisanych spritow)
      Dla kazdego wpisu (FileMetadata):
        U32 offset       (relatywny do konca tablicy metadanych)
        U32 fileSize
        U16 nameLen + bajty (filename = decimalny sprite_id, np. "5723")
      Nastepnie konkatenacja danych PNG.

    Uwaga: loader czytal 'spritesCount' jako U16, co nie pasowalo do GameSpritesU32
    (>= 191k spritow w 1098+). Zmienione na U32 w src/client/spritemanager.cpp
    ('getU16' -> 'getU32') aby format byl spojny z .spr.
    """
    items = sorted(sprites_png.items())  # po sprite_id rosnaco
    max_id = items[-1][0]

    # Buduj tablice metadanych z relatywnymi offsetami danych PNG
    meta = bytearray()
    running_offset = 0
    for sprite_id, png in items:
        name = str(sprite_id).encode("ascii")
        meta += struct.pack("<II", running_offset, len(png))
        meta += struct.pack("<H", len(name))
        meta += name
        running_offset += len(png)

    with cwm_path.open("wb") as f:
        f.write(struct.pack("<B", 0x01))           # version
        f.write(struct.pack("<I", max_id))         # spritesCount  (U32)
        f.write(struct.pack("<I", len(items)))     # entries
        f.write(meta)
        for _, png in items:
            f.write(png)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Pakuje Tibia.spr (64x64 native) -> Tibia.cwm dla OTClient."
    )
    ap.add_argument("spr", type=Path, help="sciezka do Tibia.spr (64x64 native)")
    ap.add_argument("cwm", type=Path, help="docelowa sciezka Tibia.cwm")
    args = ap.parse_args()

    print(f"[1/3] Dekodowanie {args.spr} ...")
    sprites = decode_spr(args.spr)
    if not sprites:
        raise SystemExit("Brak spritow w pliku zrodlowym.")
    print(f"      Wczytano {len(sprites)} spritow (max ID = {max(sprites)}).")

    print(f"[2/3] Kodowanie PNG ({SPRITE_SIZE}x{SPRITE_SIZE}) ...")
    encoded: dict[int, bytes] = {}
    n = len(sprites)
    for i, (sid, rgba) in enumerate(sprites.items(), 1):
        encoded[sid] = encode_png(rgba)
        if i % 5000 == 0 or i == n:
            print(f"      ... {i}/{n}")

    print(f"[3/3] Zapis {args.cwm} ...")
    encode_cwm(encoded, args.cwm)
    print(f"      Gotowe. Plik wyjsciowy: {args.cwm.stat().st_size:,} bajtow.")


if __name__ == "__main__":
    main()
