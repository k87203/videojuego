"""Export the real Windows x86_64 release template, verify startup and package a portable ZIP."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import urllib.request
import zipfile
from windows_branding import prepare_template

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', default=r'C:\Users\uriel\Downloads\Godot_v4.7.2-stable_win64_console.exe')
args = parser.parse_args()
DEST = ROOT/'build'/'Windows'
DEST.mkdir(parents=True, exist_ok=True)
(ROOT/'build'/'.gdignore').touch()
EXE = DEST/'TECNO_AVENTURA_III_0.4.1.exe'
TEMPLATE = ROOT/'.godot'/'windows-template'/'windows_release_x86_64.exe'
if not TEMPLATE.is_file():
    raise SystemExit('Install the official Godot 4.7.2 Windows templates into .godot/windows-template first.')
prepare_template(ROOT)

result = subprocess.run([args.godot, '--headless', '--path', str(ROOT), '--export-release', 'Windows Desktop', str(EXE)], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
log = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
(ROOT/'docs'/'export.log').write_text(log, encoding='utf-8')
if result.returncode or 'ERROR:' in log:
    print(log[-9000:])
    raise SystemExit(result.returncode or 1)
print(f'EXPORTED: {EXE} ({EXE.stat().st_size/1048576:.1f} MiB)', flush=True)

# Launch the export with its embedded pack from an unrelated working directory.
# No --path and no editor executable are used for this check.
smoke_cases = [('menu', []), ('characters', ['--characters'])]
smoke_cases += [(f'level{level}', [f'--level={level}', f'--character={character}']) for level, character in enumerate(['alex', 'valeria', 'diego', 'sofia'], 1)]
smoke_cases.append(('graduation', ['--graduation']))
for name, extra in smoke_cases:
    arguments = [str(EXE), '--headless', '--', '--test', '--smoke-frames=180']
    arguments += extra
    probe = subprocess.run(arguments, cwd=os.environ.get('TEMP', str(DEST)), capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
    output = probe.stdout + probe.stderr
    (ROOT/'docs'/f'export-smoke-{name}.log').write_text(output, encoding='utf-8')
    errors = [line for line in output.splitlines() if 'ERROR:' in line]
    if probe.returncode or errors or 'RUNTIME SMOKE OK:' not in output:
        print(output)
        raise SystemExit(probe.returncode or 1)
    print(f'EXPORTED RUNTIME: {name} OK', flush=True)

for filename, remote in [('Godot-LICENSE.txt', 'LICENSE.txt'), ('Godot-THIRD-PARTY.txt', 'COPYRIGHT.txt')]:
    target = DEST/filename
    if not target.exists():
        url = f'https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/{remote}'
        with urllib.request.urlopen(url, timeout=30) as response: target.write_bytes(response.read())
(DEST/'LEEME.txt').write_text('TECNO AVENTURA III - LA MISION DEL TITULO\nVersion jugable 0.4.1 para Windows x86_64\n\nAbre TECNO_AVENTURA_III_0.4.1.exe. No necesita Godot ni instalacion.\n\nA/D: mover; Espacio: salto; Shift: correr; S: deslizar; J: atacar; Q/C: habilidad; E: interactuar; Esc: pausa.\nElige entre Alex, Valeria, Diego y Sofia en Personajes.\nCompleta las tres entregas contrarreloj de cada nivel.\nContinuar recupera el ultimo checkpoint guardado y conserva partidas anteriores.\n\nElectronica original 148-180 BPM, menu neon y cuatro niveles condensados.\nArte vectorial y audio sintetizado originales. Referencias: docs/VERIFICACION.md del proyecto.\nMotor Godot 4.7.2: se incluyen sus avisos de licencia.\n', encoding='utf-8')
digest = hashlib.sha256(EXE.read_bytes()).hexdigest()
(DEST/'SHA256.txt').write_text(f'{digest}  {EXE.name}\n', encoding='ascii')
archive_path = ROOT/'build'/'TECNO_AVENTURA_III-Windows.zip'
with zipfile.ZipFile(archive_path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for name in [EXE.name, 'LEEME.txt', 'Godot-LICENSE.txt', 'Godot-THIRD-PARTY.txt', 'SHA256.txt']:
        archive.write(DEST/name, arcname='TECNO_AVENTURA_III/'+name)
with zipfile.ZipFile(archive_path, 'r') as verify:
    bad_file = verify.testzip()
    if bad_file: raise RuntimeError('ZIP verification failed: ' + bad_file)
manifest = {'version': '0.4.1', 'engine': '4.7.2.stable', 'architecture': 'x86_64', 'exe': str(EXE), 'exe_sha256': digest, 'exe_bytes': EXE.stat().st_size, 'zip': str(archive_path), 'zip_bytes': archive_path.stat().st_size, 'smoke_tests': [name for name, _ in smoke_cases]}
(ROOT/'docs'/'windows-build.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'PORTABLE ZIP: {archive_path} ({archive_path.stat().st_size/1048576:.1f} MiB)', flush=True)
print('Windows export verified. SHA256: ' + digest, flush=True)
