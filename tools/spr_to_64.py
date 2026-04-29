#!/usr/bin/env python3
"""
JEDNORAZOWA MIGRACJA: konwertuje Tibia.spr 32x32 -> Tibia.spr 64x64 (natywny format RLE).

Po konwersji:
  - ObjectBuilder zacznie widziec sprite'y jako 64x64 (gdy .otfi ma sprite-size: 64)
    -- pod warunkiem ze sam ObjectBuilder wspiera ten rozmiar (osobna sprawa)
  - OTClient zaladuje sprite'y natywnie (loadRegularSpr w spritemanager.cpp uzywa
    g_gameConfig.getSpriteSize() do parsowania), bez potrzeby pliku .cwm
  - Tibia.cwm i obejscie loadCwmSpr nie sa juz potrzebne

Istniejace 191k spritow zostanie wyskalowane algorytmem 'nearest' (kazdy piksel 2x2),
czyli wyglada identycznie jak teraz - bez zadnego rozmywania. Po migracji rysujesz nowe
sprite'y w 64x64 recznie w ObjectBuilderze, podmieniajac je tak jak dotad.

Wymaga:  pip install pillow

Uzycie:
    # Najpierw zrob backup oryginalu
    copy data\\things\\1098\\Tibia.spr data\\things\\1098\\Tibia.spr.bak

    # Wygeneruj nowy 64x64 spr (zrodlo i cel MUSZA byc rozne)
    python tools/spr_to_64.py data/things/1098/Tibia.spr.bak data/things/1098/Tibia.spr
"""

import argparse
import struct
from pathlib import Path
from PIL import Image

# Format dla protokolu 1098 (modules/game_features/features.lua):
#   GameSpritesU32          = TAK  (count + offsety jako U32, wlaczane od >= 960)
#   GameSpritesAlphaChannel = NIE  (sprite'y RGB; transparency przez RLE 'transparent runs')
HAS_U32_COUNT = True
HAS_ALPHA = False

SRC_SIZE = 32
DST_SIZE = 64

# Tradycyjny color key Tibii (magenta) - klient i tak go ignoruje przy dekodowaniu,
# ale pole 3 bajtow musi istniec w naglowku kazdego sprite'a.
COLOR_KEY = (0xFF, 0x00, 0xFF)


def decode_spr(data: bytes) -> tuple[int, dict[int, bytes]]:
    """
    Czyta .spr 32x32. Zwraca (signature, {sprite_id: bytes 32*32*4 RGBA}).
    Logika identyczna z C++ getSpriteImage() w spritemanager.cpp:239-330.
    """
    signature = struct.unpack_from("<I", data, 0)[0]
    pos = 4
    if HAS_U32_COUNT:
        count = struct.unpack_from("<I", data, pos)[0]; pos += 4
    else:
        count = struct.unpack_from("<H", data, pos)[0]; pos += 2

    offsets = struct.unpack_from(f"<{count}I", data, pos)

    sprites: dict[int, bytes] = {}
    pixel_count = SRC_SIZE * SRC_SIZE

    for sprite_id, off in enumerate(offsets, start=1):
        if off == 0:
            continue  # pusty slot

        p = off + 3  # pomijamy color key (3 bajty)
        pixel_data_size = struct.unpack_from("<H", data, p)[0]; p += 2
        end = p + pixel_data_size

        pixels = bytearray(pixel_count * 4)
        write_idx = 0

        while p < end and write_idx < pixel_count:
            transparent = struct.unpack_from("<H", data, p)[0]; p += 2
            colored     = struct.unpack_from("<H", data, p)[0]; p += 2

            write_idx = min(write_idx + transparent, pixel_count)

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

    return signature, sprites


def upscale_nearest(rgba32: bytes) -> bytes:
    """32x32 RGBA -> 64x64 RGBA przez NEAREST (kazdy piksel staje sie blokiem 2x2)."""
    img = Image.frombytes("RGBA", (SRC_SIZE, SRC_SIZE), rgba32)
    img = img.resize((DST_SIZE, DST_SIZE), Image.NEAREST)
    return img.tobytes()


def encode_sprite_rle(rgba64: bytes) -> bytes:
    """
    Koduje 64x64 RGBA -> dane RLE w formacie .spr (bez naglowka color-key/size).
    Format chunkow: U16 transparent_count, U16 colored_count, [RGB...] dla colored.
    Bez alfy (HAS_ALPHA = False).

    Optymalizacja: koniec danych obcinamy na ostatnim niepustym pikselu - klient i tak
    dopisuje przezroczystosc do konca bufora (spritemanager.cpp:306-312).
    """
    pixel_count = DST_SIZE * DST_SIZE

    # Znajdz ostatni niepelnoprzezroczysty piksel
    last_opaque = -1
    for i in range(pixel_count - 1, -1, -1):
        if rgba64[i * 4 + 3] != 0:
            last_opaque = i
            break

    if last_opaque < 0:
        # caly sprite przezroczysty - jeden chunk z samymi transparent
        return struct.pack("<HH", pixel_count, 0)

    out = bytearray()
    i = 0
    while i <= last_opaque:
        t_start = i
        while i <= last_opaque and rgba64[i * 4 + 3] == 0:
            i += 1
        transparent = i - t_start

        c_start = i
        while i <= last_opaque and rgba64[i * 4 + 3] != 0:
            i += 1
        colored = i - c_start

        out += struct.pack("<HH", transparent, colored)
        for px in range(c_start, c_start + colored):
            bi = px * 4
            out += bytes((rgba64[bi], rgba64[bi + 1], rgba64[bi + 2]))
            if HAS_ALPHA:
                out += bytes((rgba64[bi + 3],))

    return bytes(out)


def write_spr(out_path: Path, signature: int, sprites_rle: dict[int, bytes]) -> None:
    """
    Pisze plik .spr:  U32 signature, U32/U16 count, N*U32 offsetow, sprite'y.
    Sprite ID 1..max_id; brakujace ID dostaja offset=0.
    """
    max_id = max(sprites_rle)

    # Naglowki sprite'ow: 3 bajty color-key + U16 pixelDataSize + RLE
    sprite_blobs: dict[int, bytes] = {}
    for sid, rle in sprites_rle.items():
        if len(rle) > 0xFFFF:
            raise ValueError(
                f"Sprite ID {sid}: RLE = {len(rle)} bajtow, format .spr trzyma "
                f"pixelDataSize jako U16 (max 65535)."
            )
        sprite_blobs[sid] = bytes(COLOR_KEY) + struct.pack("<H", len(rle)) + rle

    header_size = 4 + (4 if HAS_U32_COUNT else 2)
    base_offset = header_size + max_id * 4

    offsets = [0] * max_id
    cursor = base_offset
    for sid in sorted(sprite_blobs):
        offsets[sid - 1] = cursor
        cursor += len(sprite_blobs[sid])

    with out_path.open("wb") as f:
        f.write(struct.pack("<I", signature))
        if HAS_U32_COUNT:
            f.write(struct.pack("<I", max_id))
        else:
            f.write(struct.pack("<H", max_id))
        f.write(struct.pack(f"<{max_id}I", *offsets))
        for sid in sorted(sprite_blobs):
            f.write(sprite_blobs[sid])


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Migracja Tibia.spr 32x32 -> Tibia.spr 64x64 (natywny format)."
    )
    ap.add_argument("src", type=Path, help="zrodlowy Tibia.spr (32x32) - np. backup .bak")
    ap.add_argument("dst", type=Path, help="docelowy Tibia.spr (64x64)")
    args = ap.parse_args()

    if args.src.resolve() == args.dst.resolve():
        ap.error("Plik zrodlowy i docelowy musza byc rozne. Najpierw zrob backup oryginalu.")

    print(f"[1/3] Wczytywanie {args.src} ...")
    data = args.src.read_bytes()
    signature, sprites = decode_spr(data)
    print(f"      Wczytano {len(sprites)} spritow (max ID = {max(sprites)}).")

    print(f"[2/3] Upscale 32 -> 64 (nearest) i kodowanie RLE ...")
    sprites_rle: dict[int, bytes] = {}
    n = len(sprites)
    for i, (sid, rgba32) in enumerate(sprites.items(), 1):
        rgba64 = upscale_nearest(rgba32)
        sprites_rle[sid] = encode_sprite_rle(rgba64)
        if i % 5000 == 0 or i == n:
            print(f"      ... {i}/{n}")

    print(f"[3/3] Zapis {args.dst} ...")
    write_spr(args.dst, signature, sprites_rle)
    print(f"      Gotowe. Plik: {args.dst.stat().st_size:,} bajtow.")


if __name__ == "__main__":
    main()
