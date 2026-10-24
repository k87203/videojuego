"""Godot import + actual-engine tests, with isolated saves and error-log enforcement."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys
import wave
import hashlib
import array
import math
from godot_path import find_godot

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot')
parser.add_argument('--routes', action='store_true')
parser.add_argument('--combat', action='store_true')
parser.add_argument('--expansion', action='store_true')
parser.add_argument('--matrix', action='store_true')
parser.add_argument('--remaster', action='store_true')
parser.add_argument('--fixes', action='store_true')
parser.add_argument('--mejoras', action='store_true')
parser.add_argument('--incentives', action='store_true')
parser.add_argument('--music', action='store_true')
args = parser.parse_args()
args.godot = find_godot(args.godot)

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
# Enemy roster audit: every kind placed in a level needs a spec, a drawing and (if new) an Aztli tip.
enemy_source = (ROOT/'scripts'/'enemy.gd').read_text(encoding='utf-8')
specs = re.findall(r'^\t"(\w+)": \{"name"', enemy_source, re.M)
roster_block = (ROOT/'scripts'/'expansion_data.gd').read_text(encoding='utf-8').split('const ENEMY_ROSTER')[1].split('\n}')[0]
roster = sorted(set(re.findall(r'"(\w+)"', roster_block)))
tips = (ROOT/'scripts'/'world.gd').read_text(encoding='utf-8').split('const ENEMY_TIPS')[1].split('\n}')[0]
draw_source = enemy_source.split('func _draw')[1]
for kind in roster:
    if kind not in specs: raise SystemExit(f'Enemy roster uses {kind} without a SPECS entry')
for kind in specs:
    if not re.search(r'^\t\t"%s"' % kind, draw_source, re.M): raise SystemExit(f'Enemy {kind} has no drawing branch')
    if kind not in ['task', 'virus', 'robot', 'clock'] and f'"{kind}"' not in tips: raise SystemExit(f'New enemy {kind} has no Aztli introduction')
print(f'ENEMY AUDIT: {len(specs)} kinds defined, {len(roster)} placed in levels, all drawn and introduced', flush=True)
print(f'ASSET AUDIT: {references} references and {len(list((ROOT/"assets"/"audio").glob("*.wav")))} WAV files OK', flush=True)

if args.music:
    names = ['modern_menu', 'urgent_chase', 'epic_boss', 'epic_final', 'teacher_suspense', 'ceremony']
    names += [f'campus_{level}{suffix}' for level in range(1, 5) for suffix in ['', '_intense']]
    fingerprints = set()
    for name in names:
        with wave.open(str(ROOT/'assets'/'audio'/(name+'.wav'))) as source:
            duration = source.getnframes()/source.getframerate()
            assert 60 <= duration <= 90 and source.getnchannels() == 2 and source.getframerate() == 32000, name
            samples = array.array('h', source.readframes(source.getnframes()))
        if sys.byteorder != 'little': samples.byteswap()
        rms = math.sqrt(sum(value*value for value in samples[::32])/len(samples[::32]))/32767
        assert 0.03 < rms <= 0.16 and max(abs(value) for value in samples) <= 27000, (name, 'mix level')
        assert max(abs(samples[i]-samples[-2+i]) for i in [0, 1])/32767 < 0.04, (name, 'loop boundary')
        fingerprints.add(hashlib.sha256(samples.tobytes()).hexdigest())
    assert len(fingerprints) == len(names), 'Tracks must be distinct original arrangements'
    print(f'MUSIC ASSET AUDIT: {len(names)} distinct loops, 60–90 seconds, moderate RMS, no clipping and smooth boundaries', flush=True)

def run(arguments, log):
    result = subprocess.run([args.godot, '--headless', '--path', str(ROOT), *arguments], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=1200 if args.routes or args.matrix else 240)
    output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout + result.stderr)
    (ROOT/'docs'/log).write_text(output, encoding='utf-8', newline='\n')
    for line in output.splitlines():
        if any(term in line for term in ['PASS:', 'FAIL', 'RESULT:', 'COMBAT', 'Level ', 'ERROR:', 'WARNING:', 'Leaked', 'still in use']):
            print(line, flush=True)
    if result.returncode or 'ERROR:' in output:
        print(output[-4500:], flush=True)
        raise SystemExit(result.returncode or 1)

run(['--editor', '--import', '--quit'], 'import.log')
print('GODOT IMPORT: OK', flush=True)
if args.music:
    run(['--fixed-fps', '60', 'res://tests/music_suite.tscn', '--', '--test'], 'music.log')
elif args.incentives:
    run(['--fixed-fps', '60', 'res://tests/incentives_suite.tscn', '--', '--test'], 'incentives.log')
elif args.mejoras:
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
    # Every enemy encounter with real damage, for every student and level.
    encounters = []
    failed_encounters = []  # run all 16, then report every failure
    for character in ['alex', 'valeria', 'diego', 'sofia']:
        for level in [1, 2, 3, 4]:
            name = f'encounters-{character}-{level}.log'
            try:
                run(['--fixed-fps', '60', 'res://tests/routes.tscn', '--', '--test', f'--route-level={level}', f'--route-character={character}', '--route-vulnerable'], name)
            except SystemExit:
                failed_encounters.append(f'{character} level {level}')
            encounters.extend(line for line in (ROOT/'docs'/name).read_text(encoding='utf-8').splitlines() if line.startswith('Level '))
    (ROOT/'docs'/'route-encounter-results.txt').write_text('\n'.join(encounters)+'\n', encoding='utf-8')
    if failed_encounters: raise SystemExit('Encounter runs failed: ' + ', '.join(failed_encounters))
elif args.expansion:
    run(['--fixed-fps', '60', 'res://tests/expansion_suite.tscn', '--', '--test'], 'expansion.log')
elif args.combat:
    run(['--fixed-fps', '60', 'res://tests/combat.tscn', '--', '--test'], 'combat.log')
elif args.routes:
    run(['--fixed-fps', '60', 'res://tests/routes.tscn', '--', '--test'], 'routes.log')
else:
    run(['--fixed-fps', '60', 'res://tests/suite.tscn', '--', '--test'], 'integration.log')
print('CHECKS PASSED; no engine errors.', flush=True)
