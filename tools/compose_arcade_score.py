"""Original arcade-electro score and a suspense score for Doctor Reprobacion.

48-bar loops, synthesized drums, Reese bass, supersaws, arpeggios and drops.
Teacher themes use heartbeat percussion, minor-second tension and string ostinati.
Derived from this project's original synthesizer, with new authored motifs.
No third-party recordings, song samples or existing song melodies are inputs.
"""
from pathlib import Path
import json
import math
import wave
import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'audio'
SR = 32000
TAU = math.tau
analysis = []


def save(name, data, bpm=0):
    data = data.astype(np.float64)
    data -= np.mean(data, axis=0)
    # Warm filters around a full cycle, preserving a clean seamless boundary.
    for sos in [butter(2, 27, 'highpass', fs=SR, output='sos'), butter(2, 11500, fs=SR, output='sos')]:
        state = np.zeros((len(sos), 2, data.shape[1]), np.float64)
        for _ in range(3):
            filtered, state = sosfilt(sos, data, axis=0, zi=state)
        data = filtered
    # A 3 ms cosine bridge removes tiny fractional-note discontinuities at the wrap.
    edge = round(.003 * SR)
    weight = (.5 - .5*np.cos(np.linspace(0, np.pi, edge)))[:, None]
    anchor = (data[0] + data[-1]) * .5
    data[:edge] = anchor*(1-weight) + data[:edge]*weight
    data[-edge:] = data[-edge:]*(1-weight) + anchor*weight
    suspense = name in ['teacher_suspense', 'epic_final']
    target = .12 if suspense else .14
    data *= target / max(1e-9, float(np.sqrt(np.mean(data**2))))
    peak = float(np.max(np.abs(data)))
    if peak > .78: data *= .78 / peak
    pcm = np.rint(data * 32767).astype('<i2')
    seconds = len(pcm) / SR
    seam = float(np.max(np.abs(pcm[0].astype(float) - pcm[-1].astype(float))) / 32767)
    assert 60 <= seconds <= 90, (name, seconds)
    assert seam < .04, (name, seam)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as track:
        track.setnchannels(2)
        track.setsampwidth(2)
        track.setframerate(SR)
        track.writeframes(pcm.tobytes())
    analysis.append(dict(name=name, bpm=bpm, seconds=seconds, bars=48,
                         style='suspense' if suspense else 'arcade-electro',
                         rms=float(np.sqrt(np.mean(data**2))), peak=float(np.max(np.abs(data))), seam_step=seam))
    print(f'ORIGINAL {name}: {seconds:.2f}s / {bpm} BPM / {analysis[-1]["style"]}', flush=True)


def compose(name, bpm, root, theme, intense=False):
    beat = 60/bpm
    n = round(48*4*beat*SR)
    drums = np.zeros((n, 2), np.float32)
    low = np.zeros_like(drums)
    music = np.zeros_like(drums)
    rng = np.random.default_rng(2094+theme)
    cache = {}
    scale = [0, 2, 3, 5, 7, 8, 10] if theme != 7 else [0, 2, 4, 5, 7, 9, 11]
    progression = [[0, 5, 2, 6], [0, 3, 5, 4], [0, 6, 3, 5], [0, 2, 5, 3]][theme % 4]
    # Independently authored phrase contours, developed across eight sections.
    contour = [[0, 2, 7, 5, 9, 7, 4, 2], [4, 7, 5, 9, 6, 11, 7, 2],
               [0, 6, 2, 9, 7, 4, 11, 5], [7, 2, 4, 9, 0, 5, 11, 7]][theme % 4]

    def add(bus, at, signal, gain, pan=0):
        start = round(at*SR) % n
        count = min(len(signal), n-start)
        stereo = np.stack((signal*math.sqrt((1-pan)/2), signal*math.sqrt((1+pan)/2)), 1)*gain
        bus[start:start+count] += stereo[:count]
        if count < len(signal): bus[:len(signal)-count] += stereo[count:]

    def tone(bus, at, midi, duration, gain, voice='lead', pan=0):
        count = round(duration*SR)
        key = (midi, count, voice)
        if key not in cache:
            t = np.arange(count, dtype=np.float32)/SR
            freq = 440*2**((midi-69)/12)
            attack = .006 if voice == 'bass' else .009
            env = np.minimum(1, t/attack)*np.minimum(1, (duration-t)/.035)
            if voice == 'sub':
                s = np.sin(TAU*freq*t)*env
            else:
                s = np.zeros(count, np.float32)
                for detune in ([.993, 1, 1.007] if voice == 'lead' else [.997, 1.003]):
                    for h in range(1, 8 if voice == 'bass' else 6):
                        if freq*h*detune < SR*.42:
                            s += np.sin(TAU*freq*h*detune*t)/(h*(3 if voice == 'lead' else 2))
                s *= env
                if voice == 'arp': s *= np.exp(-t*12)
                if voice == 'bass': s = np.tanh(s*2.5)*.65
            cache[key] = s.astype(np.float32)
        add(bus, at, cache[key], gain, pan)

    drum_cache = {}
    def drum(at, kind, gain):
        if kind not in drum_cache:
            duration = {'kick': .25, 'snare': .17, 'clap': .13, 'hat': .06, 'open': .18, 'crash': .8}[kind]
            t = np.arange(round(duration*SR), dtype=np.float32)/SR
            noise = rng.uniform(-1, 1, len(t))
            bright = noise - np.roll(noise, 1)
            if kind == 'kick':
                phase = 48*t + 6*(1-np.exp(-t*32))
                s = np.tanh(np.sin(TAU*phase)*1.9)*np.exp(-t*16)
                s += bright*np.exp(-t*500)*.17
            elif kind in ['snare', 'clap']:
                s = (bright*.52 + np.sin(TAU*185*t)*.35)*np.exp(-t*30)
                if kind == 'clap': s *= .6+.4*np.sin(TAU*130*t)**2
            else:
                s = bright*np.exp(-t*({'hat': 75, 'open': 22, 'crash': 6}[kind]))*.5
            drum_cache[kind] = (s * np.minimum(1, t / .0015)).astype(np.float32)
        add(drums, at, drum_cache[kind], gain, -.18 if kind in ['hat', 'open'] else 0)

    for bar in range(48):
        phrase = bar//8
        drop = phrase in [1, 2, 4, 5]
        build = phrase in [0, 3]
        breakdown = phrase == 3 and bar % 8 < 4
        drive = (1 if drop else (.72 if build else .45)) * (1 if intense else .8)
        degree = progression[(bar//2) % 4]
        chord = root + scale[degree]
        if not breakdown:
            for b in range(4):
                kick_on = not (theme == 3 and b == 1)
                if kick_on: drum((bar*4+b)*beat, 'kick', .65*drive)
                if b % 2: drum((bar*4+b)*beat, 'snare', .32*drive)
                drum((bar*4+b+.5)*beat, 'open', .18*drive)
                for off in ([.25, .75] if drop or intense else [.75]):
                    drum((bar*4+b+off)*beat, 'hat', .13*drive)
            if theme == 3: drum((bar*4+2.75)*beat, 'kick', .36)
        if bar % 8 == 0: drum(bar*4*beat, 'crash', .28)
        if bar % 8 == 7:
            for j in range(8): drum((bar*4+2+j*.25)*beat, 'snare', .07+j*.018)
        for b in range(4):
            if breakdown and b % 2: continue
            tone(low, (bar*4+b+.0)*beat, chord-24, beat*.8, .38*drive, 'sub')
            for off in ([.0, .5] if drop or intense else [.5]):
                midi = chord-12+(7 if b == 3 and bar % 2 else 0)
                tone(low, (bar*4+b+off)*beat, midi, beat*.42, .29*drive, 'bass')
        for step in range(8):
            if breakdown and step % 2: continue
            value = contour[(step+bar % 4) % 8]
            value += 2 if phrase in [2, 5] and step >= 4 else 0
            midi = root+12+scale[value % 7]+12*(value//7)
            if bar % 4 == 3 and step > 5: midi -= 12
            voice = 'lead' if drop else 'arp'
            tone(music, (bar*4+step*.5)*beat, midi, beat*(.43 if drop else .3),
                 .16 if intense and drop else .115, voice, .18*math.sin(step+bar))
            if intense or theme == 3:
                tone(music, (bar*4+step*.5+.25)*beat, midi+12, beat*.18, .045, 'arp', -.4)
        for third in [0, 3, 7]:
            tone(music, bar*4*beat, chord+third, beat*3.9, .035 if breakdown else .017, 'lead', -.35 if third == 0 else .35)
        if bar in [6, 14, 30, 38, 46]:
            duration = beat*8
            t = np.arange(round(duration*SR), dtype=np.float32)/SR
            noise = rng.uniform(-1, 1, len(t))
            rise = (t/duration)**2
            signal = (noise*.12+np.sin(TAU*(180*t+1100*t*t/duration))*.06)*rise
            add(music, bar*4*beat, signal, .9)
    # Pump pads, leads and bass around every kick; leave the transients intact.
    phase = (np.arange(n, dtype=np.float32)/SR) % beat
    duck = .22+.78*(1-np.exp(-phase*22))
    low *= duck[:, None]
    music *= (.55+.45*duck)[:, None]
    music += np.roll(music[:, ::-1], round(beat*.75*SR), 0)*.20
    data = np.tanh((drums+low+music)*1.25)
    save(name, data, bpm)


def compose_suspense(name, bpm, final=False):
    beat = 60.0 / bpm
    n = round(48 * 4 * beat * SR)
    data = np.zeros((n, 2), np.float32)
    rng = np.random.default_rng(51409 + int(final))
    cache = {}

    def add(at, signal, gain, pan=0):
        start = round(at * SR) % n
        length = min(len(signal), n-start)
        stereo = np.column_stack((signal*math.sqrt((1-pan)/2), signal*math.sqrt((1+pan)/2))) * gain
        data[start:start+length] += stereo[:length]
        if length < len(signal): data[:len(signal)-length] += stereo[length:]

    def tone(at, midi, duration, gain, voice='pluck', pan=0):
        key = (midi, round(duration*SR), voice)
        if key not in cache:
            t = np.arange(key[1], dtype=np.float32)/SR
            f = 440*2**((midi-69)/12)
            if voice == 'strings':
                signal = np.zeros(len(t), np.float32)
                for detune in [.996, 1.004]:
                    for h in range(1, 6): signal += np.sin(TAU*f*h*detune*t)/(h*3)
                signal *= (.72+.28*np.sin(TAU*6*t)**2)
                attack, release = .13, .25
            else:
                signal = (np.sin(TAU*f*t)+.24*np.sin(TAU*f*2*t))*np.exp(-t*(7 if voice == 'pluck' else 3))
                attack, release = .006, .035
            signal *= np.minimum(1, t/attack)*np.minimum(1, (duration-t)/release)
            cache[key] = signal.astype(np.float32)
        add(at, cache[key], gain, pan)

    t = np.arange(round(.27*SR), dtype=np.float32)/SR
    heartbeat = np.sin(TAU*(45*t+3*(1-np.exp(-t*28))))*np.exp(-t*20)*np.minimum(1, t/.003)
    t2 = np.arange(round(.10*SR), dtype=np.float32)/SR
    tick = rng.uniform(-1, 1, len(t2))*np.exp(-t2*65)*np.minimum(1, t2/.002)*.15
    t3 = np.arange(round(.18*SR), dtype=np.float32)/SR
    snare = (rng.uniform(-1, 1, len(t3))*.40+np.sin(TAU*165*t3)*.22)*np.exp(-t3*30)*np.minimum(1, t3/.002)
    root = 47
    pattern = [0, 0, 1, 0, 7, 6, 1, 0]
    for bar in range(48):
        base = bar*4*beat
        section = bar//8
        tension = .65 if section == 3 else (1.15 if section in [2, 4, 5] else .85)
        for offset in [0, .45, 2, 2.45]: add(base+offset*beat, heartbeat, .50*tension)
        for step in range(8):
            add(base+step*.5*beat, tick, .15, -.3 if step%2 else .3)
            midi = root+12+pattern[(step+bar%2*2)%8]
            if section in [1, 2, 4, 5] or final:
                tone(base+step*.5*beat, midi, beat*.42, .15*tension, 'pluck', .2 if step%2 else -.2)
        for offset in [0, 2]: tone(base+offset*beat, root-12+(1 if bar%8==7 else 0), beat*1.7, .38, 'bass')
        if bar%2 == 0:
            for interval, gain in [(0, .08), (3, .07), (7, .07), (13, .025)]:
                tone(base, root+12+interval, beat*7.8, gain*tension, 'strings', -.3 if interval%2 else .3)
        if section in [2, 4, 5] or final:
            for offset in [1, 3]: add(base+offset*beat, snare, .24 if final else .13)
        if final:
            for offset in [.5, 1.5, 3]: tone(base+offset*beat, root+24+[0, 1, 6][int(offset)%3], beat*.32, .09, 'strings')
        if bar%8 == 7:
            duration = beat*4
            rise_t = np.arange(round(duration*SR), dtype=np.float32)/SR
            rise = rng.uniform(-1, 1, len(rise_t))*(np.sin(np.pi*rise_t/duration)**2)*.055
            add(base, rise, 1)
    data += np.roll(data[:, ::-1], round(beat*.75*SR), axis=0)*.17
    save(name, np.tanh(data*1.25), bpm)


if __name__ == '__main__':
    for level, bpm, root in [(1, 160, 57), (2, 164, 60), (3, 172, 54), (4, 168, 59)]:
        compose(f'campus_{level}', bpm, root, level)
        compose(f'campus_{level}_intense', bpm, root, level, True)
    for name, bpm, root, theme in [('modern_menu', 156, 57, 5), ('urgent_chase', 180, 54, 6), ('epic_boss', 174, 52, 4), ('ceremony', 152, 60, 7)]:
        compose(name, bpm, root, theme, True)
    compose_suspense('teacher_suspense', 160)
    compose_suspense('epic_final', 176, True)
    (ROOT/'docs'/'campus-loops-analysis.json').write_text(json.dumps({
        'method': 'Original arcade-electro synthesis, authored motifs, Reese/sub bass, supersaws, drops and arpeggios. Teacher suspense: heartbeat percussion, dissonant strings and ostinati. No third-party recordings or song inputs.',
        'sample_rate': SR, 'tracks': analysis}, indent=2), encoding='utf-8')
