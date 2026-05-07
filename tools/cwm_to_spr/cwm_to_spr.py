#!/usr/bin/env python3
"""
Konwerter Tibia.cwm -> Tibia.spr (natywny format RLE).

Czyta plik .cwm uzywany przez OTClient, dekoduje PNG dla kazdego sprite'a i zapisuje
standardowy .spr. Domyslne ustawienia sa zgodne z protokolem 1098 w tym repo:
  - count jako U32 (GameSpritesU32 = TAK)
  - bez kanalu alpha w danych SPR (GameSpritesAlphaChannel = NIE)
  - sprite-size 64

CWM nie przechowuje oryginalnej sygnatury .spr. Jesli potrzebujesz tej samej
sygnatury co w starym pliku, uzyj --signature-from albo --signature.

Wymaga:  pip install pillow

Uzycie:
    python tools/cwm_to_spr.py data/things/1098/Tibia.cwm data/things/1098/Tibia.spr \
        --signature-from data/things/1098/Tibia.spr.bak

    python tools/cwm_to_spr.py data/things/1098/Tibia.cwm data/things/1098/Tibia.spr \
        --signature 0x12345678
"""

import argparse
import io
import struct
from pathlib import Path
from PIL import Image

HAS_U32_COUNT = True
HAS_ALPHA = False
SPRITE_SIZE = 64
COLOR_KEY = (0xFF, 0x00, 0xFF)


def parse_int(value: str) -> int:
    """Pozwala podac liczbe dziesietnie albo hex, np. 305419896 lub 0x12345678."""
    return int(value, 0)


def read_signature_from_spr(path: Path) -> int:
    data = path.read_bytes()
    if len(data) < 4:
        raise ValueError(f"{path}: plik jest za krotki, aby odczytac sygnature SPR.")
    return struct.unpack_from("<I", data, 0)[0]


def decode_cwm(cwm_path: Path, sprite_size: int) -> tuple[int, dict[int, bytes]]:
    """
    Czyta .cwm i zwraca (sprites_count, {sprite_id: bytes(N*N*4) RGBA}).
    Format odpowiada encode_cwm() z tools/spr_to_cwm.py.
    """
    data = cwm_path.read_bytes()
    if len(data) < 9:
        raise ValueError(f"{cwm_path}: plik jest za krotki na naglowek CWM.")

    pos = 0
    version = data[pos]
    pos += 1
    if version != 0x01:
        raise ValueError(f"{cwm_path}: nieobslugiwana wersja CWM: {version}.")

    sprites_count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    entries = struct.unpack_from("<I", data, pos)[0]
    pos += 4

    metadata: list[tuple[int, int, int]] = []
    for _ in range(entries):
        offset, file_size = struct.unpack_from("<II", data, pos)
        pos += 8
        name_len = struct.unpack_from("<H", data, pos)[0]
        pos += 2
        name = data[pos:pos + name_len].decode("ascii")
        pos += name_len
        metadata.append((int(name), offset, file_size))

    data_start = pos
    sprites: dict[int, bytes] = {}

    for sprite_id, offset, file_size in metadata:
        start = data_start + offset
        end = start + file_size
        if start < data_start or end > len(data):
            raise ValueError(f"{cwm_path}: sprite ID {sprite_id} wskazuje poza plik.")

        img = Image.open(io.BytesIO(data[start:end])).convert("RGBA")
        if img.size != (sprite_size, sprite_size):
            raise ValueError(
                f"{cwm_path}: sprite ID {sprite_id} ma rozmiar {img.size}, "
                f"oczekiwano {sprite_size}x{sprite_size}."
            )
        sprites[sprite_id] = img.tobytes()

    return sprites_count, sprites


def encode_sprite_rle(rgba: bytes, sprite_size: int, has_alpha: bool) -> bytes:
    """
    Koduje RGBA -> dane RLE .spr (bez 3-bajtowego color key i bez U16 data size).
    Dla has_alpha=False przezroczystosc jest zapisana jako transparent runs, a alfa
    kolorowych pikseli jest pomijana.
    """
    pixel_count = sprite_size * sprite_size
    channels = 4 if has_alpha else 3

    last_colored = -1
    for i in range(pixel_count - 1, -1, -1):
        if rgba[i * 4 + 3] != 0:
            last_colored = i
            break

    if last_colored < 0:
        return struct.pack("<HH", pixel_count, 0)

    out = bytearray()
    i = 0
    while i <= last_colored:
        transparent_start = i
        while i <= last_colored and rgba[i * 4 + 3] == 0:
            i += 1
        transparent = i - transparent_start

        colored_start = i
        while i <= last_colored and rgba[i * 4 + 3] != 0:
            i += 1
        colored = i - colored_start

        out += struct.pack("<HH", transparent, colored)
        for px in range(colored_start, colored_start + colored):
            bi = px * 4
            out += bytes((rgba[bi], rgba[bi + 1], rgba[bi + 2]))
            if channels == 4:
                out += bytes((rgba[bi + 3],))

    return bytes(out)


def write_spr(
    out_path: Path,
    signature: int,
    sprites_count: int,
    sprites_rle: dict[int, bytes],
    has_u32_count: bool,
) -> None:
    """Pisze .spr: U32 signature, U32/U16 count, offsety U32, potem bloby sprite'ow."""
    max_sprite_id = max(sprites_rle) if sprites_rle else 0
    count = max(sprites_count, max_sprite_id)
    if not has_u32_count and count > 0xFFFF:
        raise ValueError(f"count={count} nie miesci sie w U16. Uzyj formatu U32.")

    sprite_blobs: dict[int, bytes] = {}
    for sprite_id, rle in sprites_rle.items():
        if len(rle) > 0xFFFF:
            raise ValueError(
                f"Sprite ID {sprite_id}: RLE = {len(rle)} bajtow, a .spr trzyma "
                f"pixelDataSize jako U16 (max 65535)."
            )
        sprite_blobs[sprite_id] = bytes(COLOR_KEY) + struct.pack("<H", len(rle)) + rle

    header_size = 4 + (4 if has_u32_count else 2)
    base_offset = header_size + count * 4
    offsets = [0] * count

    cursor = base_offset
    for sprite_id in sorted(sprite_blobs):
        if sprite_id <= 0:
            raise ValueError(f"Nieprawidlowe sprite ID: {sprite_id}.")
        offsets[sprite_id - 1] = cursor
        cursor += len(sprite_blobs[sprite_id])

    with out_path.open("wb") as f:
        f.write(struct.pack("<I", signature))
        if has_u32_count:
            f.write(struct.pack("<I", count))
        else:
            f.write(struct.pack("<H", count))
        if offsets:
            f.write(struct.pack(f"<{count}I", *offsets))
        for sprite_id in sorted(sprite_blobs):
            f.write(sprite_blobs[sprite_id])


def main() -> None:
    ap = argparse.ArgumentParser(description="Konwertuje Tibia.cwm -> Tibia.spr.")
    ap.add_argument("cwm", type=Path, help="zrodlowy Tibia.cwm")
    ap.add_argument("spr", type=Path, help="docelowy Tibia.spr")
    ap.add_argument("--sprite-size", type=int, default=SPRITE_SIZE, help="rozmiar sprite'a, domyslnie 64")
    ap.add_argument("--signature", type=parse_int, default=0, help="sygnatura SPR, np. 0x12345678")
    ap.add_argument("--signature-from", type=Path, help="skopiuj sygnature z istniejacego pliku .spr")
    ap.add_argument("--u16-count", action="store_true", help="zapisz count jako U16 zamiast U32")
    ap.add_argument("--alpha", action="store_true", help="zapisz kanal alpha w danych SPR")
    args = ap.parse_args()

    signature = read_signature_from_spr(args.signature_from) if args.signature_from else args.signature

    print(f"[1/3] Wczytywanie {args.cwm} ...")
    sprites_count, sprites = decode_cwm(args.cwm, args.sprite_size)
    if not sprites:
        raise SystemExit("Brak spritow w pliku zrodlowym.")
    print(f"      Wczytano {len(sprites)} spritow (count = {sprites_count}, max ID = {max(sprites)}).")

    print(f"[2/3] Kodowanie RLE ({args.sprite_size}x{args.sprite_size}) ...")
    sprites_rle: dict[int, bytes] = {}
    n = len(sprites)
    for i, (sprite_id, rgba) in enumerate(sprites.items(), 1):
        sprites_rle[sprite_id] = encode_sprite_rle(rgba, args.sprite_size, args.alpha)
        if i % 5000 == 0 or i == n:
            print(f"      ... {i}/{n}")

    print(f"[3/3] Zapis {args.spr} ...")
    write_spr(args.spr, signature, sprites_count, sprites_rle, not args.u16_count)
    print(f"      Gotowe. Plik: {args.spr.stat().st_size:,} bajtow.")


if __name__ == "__main__":
    main()
