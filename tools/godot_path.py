"""Resolve the engine without machine-specific absolute paths."""
from pathlib import Path
import os
import shutil


def find_godot(requested=None):
    for candidate in [requested, os.environ.get('GODOT'), shutil.which('godot'), shutil.which('godot4')]:
        if not candidate:
            continue
        if Path(candidate).expanduser().is_file():
            return str(Path(candidate).expanduser().resolve())
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    for name in ['Godot_v4.7.2-stable_win64_console.exe', 'Godot_v4.7.2-stable_win64.exe']:
        candidate = Path.home()/'Downloads'/name
        if candidate.is_file():
            return str(candidate)
    raise SystemExit('Godot not found. Pass --godot, set GODOT, or add godot/godot4 to PATH.')
