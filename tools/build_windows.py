"""Export the current game with standard Godot templates and verify its portable ZIP."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from godot_path import find_godot

ROOT = Path(__file__).resolve().parents[1]


def run(command, log, timeout=240, cwd=None):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=timeout)
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    (ROOT/'docs'/log).write_text(output, encoding='utf-8', newline='\n')
    if result.returncode or 'ERROR:' in output:
        print(output[-9000:])
        raise SystemExit(result.returncode or 1)
    return output


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot')
    args = parser.parse_args()
    godot = find_godot(args.godot)
    destination = ROOT/'build'/'Windows'
    destination.mkdir(parents=True, exist_ok=True)
    (ROOT/'build'/'.gdignore').touch()
    (ROOT/'docs').mkdir(exist_ok=True)
    executable = destination/'TECNO_AVENTURA_III.exe'
    run([godot, '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'], 'export-import.log')
    run([godot, '--headless', '--path', str(ROOT), '--export-release', 'Windows Desktop', str(executable)], 'export.log')
    cases = [('menu', []), ('characters', ['--characters'])]
    cases += [(f'level{level}', [f'--level={level}']) for level in range(1, 5)]
    cases += [('shop', ['--collection=shop']), ('gallery', ['--collection=gallery']),
              ('records', ['--collection=records']), ('pause', ['--level=1', '--paused']),
              ('graduation', ['--graduation'])]
    for name, extra in cases:
        command = [str(executable), '--headless', '--', '--test', '--smoke-frames=120', *extra]
        output = run(command, f'export-smoke-{name}.log', timeout=60, cwd=tempfile.gettempdir())
        if 'RUNTIME SMOKE OK:' not in output:
            raise SystemExit(f'Exported runtime did not complete: {name}')
        print(f'EXPORTED RUNTIME: {name} OK', flush=True)
    for name in ['Godot-LICENSE.txt', 'Godot-THIRD-PARTY.txt']:
        shutil.copy2(ROOT/'licenses'/name, destination/name)
    (destination/'LEEME.txt').write_text(
        'TECNO AVENTURA III - version 0.5\n\n'
        'Abre TECNO_AVENTURA_III.exe. No necesita Godot, Python ni instalacion.\n'
        'A/D: mover; Espacio: saltar; Shift: correr; S: deslizar; J: atacar; Q: habilidad; E: interactuar; Esc: pausa.\n'
        'Incluye seis personajes, tienda, galeria, logros y musica original.\n'
        'Licencias del motor: Godot-LICENSE.txt y Godot-THIRD-PARTY.txt.\n', encoding='utf-8')
    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
    (destination/'SHA256.txt').write_text(f'{digest}  {executable.name}\n', encoding='ascii')
    package = ROOT/'build'/'TECNO_AVENTURA_III-Windows.zip'
    names = [executable.name, 'LEEME.txt', 'SHA256.txt', 'Godot-LICENSE.txt', 'Godot-THIRD-PARTY.txt']
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in names: archive.write(destination/name, arcname='TECNO_AVENTURA_III/'+name)
    with zipfile.ZipFile(package) as archive:
        if archive.testzip(): raise SystemExit('Portable ZIP verification failed')
    (ROOT/'docs'/'windows-build.json').write_text(json.dumps({
        'version': '0.5', 'exe': executable.name, 'exe_sha256': digest,
        'exe_bytes': executable.stat().st_size, 'zip_bytes': package.stat().st_size,
        'smoke_tests': [name for name, _ in cases]}, indent=2), encoding='utf-8')
    print(f'WINDOWS EXPORT VERIFIED: {package} / {package.stat().st_size/1048576:.1f} MiB', flush=True)


if __name__ == '__main__':
    main()
