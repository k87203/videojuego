"""Godot import + actual-engine tests, with isolated saves and error-log enforcement."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', default=os.environ.get('GODOT', shutil.which('godot') or r'C:\Users\uriel\Downloads\Godot_v4.7.2-stable_win64_console.exe'))
parser.add_argument('--routes', action='store_true')
parser.add_argument('--combat', action='store_true')
parser.add_argument('--expansion', action='store_true')
parser.add_argument('--matrix', action='store_true')
parser.add_argument('--remaster', action='store_true')
parser.add_argument('--fixes', action='store_true')
parser.add_argument('--mejoras', action='store_true')
args = parser.parse_args()

references = 0
for folder in ['scripts', 'scenes', 'tests']:
    for file in (ROOT/folder).glob('*'):
        if file.suffix not in ['.gd', '.tscn']: continue
        for path in re.findall(r'"res://([^"%]*\.(?:gd|tscn|wav|svg))"', file.read_text(encoding='utf-8')):
            if not (ROOT/path).exists():
                raise SystemExit(f'Missing reference in {file.name}: {path}')
            references += 1
for file in (ROOT/'assets'/'audio').glob('*.wav'):
    with wave.open(str(file)) as track:
        assert track.getnframes() > 0 and track.getsampwidth() == 2, file
print(f'ASSET AUDIT: {references} references and {len(list((ROOT/"assets"/"audio").glob("*.wav")))} WAV files OK', flush=True)

def run(arguments, log):
    result = subprocess.run([args.godot, '--headless', '--path', str(ROOT), *arguments], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=1200 if args.routes else 240)
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    (ROOT/'docs'/log).write_text(output, encoding='utf-8')
    for line in output.splitlines():
        if any(term in line for term in ['PASS:', 'FAIL', 'RESULT:', 'COMBAT', 'Level ', 'ERROR:', 'WARNING:', 'Leaked', 'still in use']):
            print(line, flush=True)
    if result.returncode or 'ERROR:' in output:
        print(output[-4500:], flush=True)
        raise SystemExit(result.returncode or 1)

run(['--editor', '--import', '--quit'], 'import.log')
print('GODOT IMPORT: OK', flush=True)
if args.mejoras:
    run(['--fixed-fps', '60', 'res://tests/mejoras_suite.tscn', '--', '--test'], 'mejoras.log')
elif args.fixes:
    run(['--fixed-fps', '60', 'res://tests/fixes_suite.tscn', '--', '--test'], 'fixes.log')
elif args.remaster:
    run(['--fixed-fps', '60', 'res://tests/remaster_suite.tscn', '--', '--test'], 'remaster.log')
elif args.matrix:
    lines = []
    for character in ['alex', 'valeria', 'diego', 'sofia']:
        for start in [17400, 70200]:
            name = f'routes-{character}-{start}.log'
            run(['--fixed-fps', '60', 'res://tests/routes.tscn', '--', '--test', f'--route-start={start}', '--route-length=4800', f'--route-character={character}'], name)
            lines.extend(line for line in (ROOT/'docs'/name).read_text(encoding='utf-8').splitlines() if line.startswith('Level '))
    (ROOT/'docs'/'route-matrix-results.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
elif args.expansion:
    run(['--fixed-fps', '60', 'res://tests/expansion_suite.tscn', '--', '--test'], 'expansion.log')
elif args.combat:
    run(['--fixed-fps', '60', 'res://tests/combat.tscn', '--', '--test'], 'combat.log')
elif args.routes:
    run(['--fixed-fps', '60', 'res://tests/routes.tscn', '--', '--test'], 'routes.log')
else:
    run(['--fixed-fps', '60', 'res://tests/suite.tscn', '--', '--test'], 'integration.log')
print('CHECKS PASSED; no engine errors.', flush=True)
