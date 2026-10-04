#!/usr/bin/env python3
"""Affiche un sprite de la ROM graphique Dig Dug dans le terminal."""

from __future__ import annotations

import argparse
from pathlib import Path


DEFAULT_ROM = Path(r"C:\Users\yannv\Documents\Projets_HW\DigDug\roms\dd1.15")

# Index de couleur: 0 = couleur 1, ..., 3 = couleur 4.
COLORS = (
    (0, 0, 0),        # couleur 1: noir
    (0, 0, 255),      # couleur 2: bleu
    (255, 255, 255),  # couleur 3: blanc
    (0, 0, 255),      # couleur 4: bleu
)


def read_sprite(data: bytes, sprite_id: int) -> list[list[int]]:
    """Retourne les 16 lignes de 16 pixels d'un sprite."""
    rows: list[list[int]] = []

    for line in range(16):
        bank = line // 8
        rom_line = line % 8
        pixels: list[int] = []

        for horizontal_bitmap in range(4):
            address = (sprite_id << 6) | (bank << 5) | (horizontal_bitmap << 3) | rom_line
            value = data[address]
            for bit in range(4):
                high_plane = (value >> (7 - bit)) & 1
                low_plane = (value >> (3 - bit)) & 1
                pixels.append((high_plane << 1) | low_plane)

        rows.append(pixels)

    return rows


def print_sprite(sprite: list[list[int]], sprite_id: int) -> None:
    """Affiche le sprite avec deux espaces par pixel pour garder les proportions."""
    reset = "\033[0m"
    print(f"Sprite {sprite_id} (16 x 16 pixels)")
    for line, row in enumerate(sprite):
        address = (sprite_id << 6) | ((line // 8) << 5) | (line % 8)
        rendered = []
        for color_index in row:
            red, green, blue = COLORS[color_index]
            rendered.append(f"\033[48;2;{red};{green};{blue}m  {reset}")
        print(f"0x{address:03X}: {''.join(rendered)}")


def get_sprite_id(value: str | None) -> int:
    """Lit un ID fourni en argument ou demande sa valeur à l'utilisateur."""
    raw_value = value if value is not None else input("ID du sprite (0-31) : ")
    try:
        sprite_id = int(raw_value, 0)
    except ValueError as error:
        raise ValueError("L'ID du sprite doit être un entier de 0 à 31.") from error
    if not 0 <= sprite_id <= 31:
        raise ValueError("L'ID du sprite doit être compris entre 0 et 31.")
    return sprite_id


def main() -> int:
    parser = argparse.ArgumentParser(description="Afficher un sprite de dd1.11.")
    parser.add_argument("sprite_id", nargs="?", help="ID du sprite (0-31) ou 'all'")
    parser.add_argument("--rom", type=Path, default=DEFAULT_ROM, help="Chemin de la ROM")
    args = parser.parse_args()

    try:
        selection = args.sprite_id
        if selection is None:
            selection = input("ID du sprite (0-31) ou 'all' : ").strip()
        data = args.rom.read_bytes()
        if len(data) < 4096:
            raise ValueError("La ROM doit contenir au moins 4096 octets.")
        sprite_ids = range(32) if selection.lower() == "all" else (get_sprite_id(selection),)
        for sprite_id in sprite_ids:
            print_sprite(read_sprite(data, sprite_id), sprite_id)
    except (OSError, ValueError) as error:
        print(f"Erreur : {error}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())