#!/usr/bin/env python3
"""Affiche graphiquement les tuiles contenues dans un fichier ROM.

Chaque tile est composée de 8 octets (8 lignes de 8 pixels).
Le script affiche toutes les tuiles en grille dans le terminal.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import sys

# Tableau hex intégré fourni par l'utilisateur
COLOR_TABLE = [
    0x00, 0x2F, 0xF6, 0x1E, 0x28, 0x0D, 0x36, 0x04,
    0x80, 0x5B, 0x07, 0xA4, 0x52, 0x5A, 0x65, 0x00,
    0x00, 0x07, 0x2F, 0x28, 0xE8, 0xF6, 0x36, 0x1F,
    0x65, 0x14, 0x0A, 0xDF, 0xD8, 0xD0, 0x84, 0x00,
]


def extract_rom_data(data: bytes) -> bytes:
    header_start = b"memory_initialization_radix=16;"
    vector_start = b"memory_initialization_vector="
    if not data.startswith(header_start):
        return data

    idx = data.find(vector_start, len(header_start))
    if idx == -1:
        return data

    idx += len(vector_start)
    payload = data[idx:]
    # Remove whitespace and separators, keep hex digits
    filtered = bytes(ch for ch in payload if ch in b"0123456789ABCDEFabcdef")
    if len(filtered) % 2 != 0:
        filtered = filtered[:-1]
    try:
        return bytes.fromhex(filtered.decode("ascii"))
    except Exception:
        return payload


def rgb_from_color_entry(entry: int) -> tuple[int, int, int]:
    blue = (entry >> 6) & 0x03
    green = (entry >> 3) & 0x07
    red = entry & 0x07
    return (
        int(red * 255 / 7),
        int(green * 255 / 7),
        int(blue * 255 / 3),
    )


def render_tiles(data: bytes, bytes_per_tile: int = 8, cols: int = 16, on_char: str = "█", off_char: str = " ", scale: int = 1, invert: bool = False) -> str:
    if bytes_per_tile <= 0:
        raise ValueError("bytes_per_tile must be > 0")

    # split into tiles
    tiles = [data[i:i+bytes_per_tile] for i in range(0, len(data), bytes_per_tile)]
    # pad last tile if needed
    if tiles and len(tiles[-1]) < bytes_per_tile:
        tiles[-1] = tiles[-1] + bytes(bytes_per_tile - len(tiles[-1]))

    if invert:
        on_char, off_char = off_char, on_char

    lines: list[str] = []
    for idx, t in enumerate(tiles):
        color_idx = idx & 0x0F
        color_entry = COLOR_TABLE[color_idx] if color_idx < len(COLOR_TABLE) else 0x00
        r, g, b = rgb_from_color_entry(color_entry)
        color_code = f"\x1b[38;2;{r};{g};{b}m"
        reset_code = "\x1b[0m"
        colored_on = f"{color_code}{on_char}{reset_code}"
        lines.append(f"Tile {idx} (0x{idx:02X}) color idx={color_idx} rgb=({r},{g},{b}):")
        for y in range(bytes_per_tile):
            row_pixels: list[str] = []
            b = t[y] if y < len(t) else 0
            for bit in range(8):
                pixel = colored_on if (b >> (7 - bit)) & 1 else off_char
                row_pixels.append(pixel * scale)
            lines.append(''.join(row_pixels))
        lines.append('')
    return '\n'.join(lines)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Afficher les tuiles d'un fichier ROM (8x8 pixels par tile).")
    p.add_argument("--file", "-f", required=False, default=r"C:\\Users\\yannv\\Documents\\Projets_HW\\DigDug\\roms", help="Chemin vers le fichier binaire contenant les tiles")
    p.add_argument("--cols", "-c", type=int, default=16, help="Nombre de tiles par ligne")
    p.add_argument("--bytes-per-tile", "-b", type=int, default=8, help="Octets par tile (hauteur) - défaut 8")
    p.add_argument("--scale", "-s", type=int, default=1, help="Échelle horizontale (répéter pixels)")
    p.add_argument("--dot", action="store_true", help="Afficher les pixels éteints avec un point '.' au lieu d'un espace")
    p.add_argument("--invert", action="store_true", help="Inverser on/off")
    args = p.parse_args(argv)

    path = Path(args.file)
    if not path.exists():
        print(f"Fichier introuvable: {path}")
        return 2

    # If the given path is a directory, try to pick a ROM file inside it.
    if path.is_dir():
        entries = [p for p in path.iterdir() if p.is_file()]
        rom_file = None
        # prefer common ROM/binary extensions
        preferred_exts = [".bin", ".rom", ".hex", ".mif"]
        for ext in preferred_exts:
            for p in entries:
                if p.suffix.lower() == ext:
                    rom_file = p
                    break
            if rom_file:
                break
        # fallback to first file found
        if not rom_file and entries:
            rom_file = entries[0]

        if not rom_file:
            print(f"Aucun fichier ROM trouvé dans le dossier: {path}")
            return 2

        print(f"Utilisation du fichier trouvé: {rom_file}")
        path = rom_file

    try:
        data = path.read_bytes()
    except PermissionError as e:
        print(f"Erreur lecture fichier (permission): {path} - {e}")
        return 3
    except IsADirectoryError:
        print(f"Chemin inattendu: {path} est un dossier.")
        return 3
    except Exception as e:
        print(f"Erreur lecture fichier: {e}")
        return 3

    data = extract_rom_data(data)
    off_char = '.' if args.dot else ' '
    out = render_tiles(data, bytes_per_tile=args.bytes_per_tile, cols=args.cols, on_char='█', off_char=off_char, scale=args.scale, invert=args.invert)
    print(out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
