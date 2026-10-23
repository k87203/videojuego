"""Rebuild all original vector scenery and synthesized audio (Python standard library).
No external assets or protected melodies. Music is an original provisional synth score.
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets' / 'art'
AUDIO = ROOT / 'assets' / 'audio'
ART.mkdir(parents=True, exist_ok=True)
AUDIO.mkdir(parents=True, exist_ok=True)

def svg(name, body, w=1600, h=720):
    (ART / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>', encoding='utf-8')

svg('icon.svg', '<rect width="128" height="128" rx="28" fill="#15314c"/><path d="M14 50 64 23 114 50 64 77Z" fill="#f4cc7e"/><path d="M35 67V88Q64 110 93 88V67L64 83Z" fill="#6edbc8"/><path d="M108 52V90" stroke="#f4cc7e" stroke-width="5"/>', 128, 128)

palettes = [('#9bd9de', '#edf0d4', '#94bdb6', '#f4dfb3', '#d6bb93', '#467b8d'),
            ('#91b7ce', '#eee0ce', '#7894ac', '#e8d0b3', '#bf957d', '#476982'),
            ('#132c4c', '#41617a', '#37516e', '#43617a', '#304760', '#70b9c3'),
            ('#505b8b', '#ebc8b0', '#7c7899', '#dac5b3', '#b59a9c', '#4d6689')]

for idx, (top, bottom, far, wall, side, glass) in enumerate(palettes, 1):
    sky = f'<defs><linearGradient id="s" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs><path fill="url(#s)" d="M0 0H1600V720H0Z"/>'
    sky += '<circle cx="1200" cy="170" r="68" fill="#fff4d8" opacity=".65"/><circle cx="1200" cy="170" r="99" fill="#fff4d8" opacity=".10"/>'
    if idx != 3:
        for x,y in [(60,110),(380,180),(790,95),(1390,240)]:
            sky += f'<g fill="#fff9eb" opacity=".48"><ellipse cx="{x}" cy="{y}" rx="95" ry="16"/><ellipse cx="{x+35}" cy="{y-12}" rx="50" ry="22"/></g>'
    else:
        rng = random.Random(44)
        for _ in range(70):
            sky += f'<circle cx="{rng.randrange(1600)}" cy="{rng.randrange(410)}" r="1.4" fill="#d7eeef" opacity=".65"/>'
    sky += f'<path d="M0 425 140 330 280 390 440 280 680 410 850 340 1020 415 1220 300 1400 380 1600 310V720H0Z" fill="{far}" opacity=".4"/>'
    svg(f'sky{idx}.svg', sky)
    art = ''
    for j, (x, y, width, height) in enumerate([(0,315,330,290),(360,235,500,370),(900,300,300,305),(1250,260,350,345)]):
        art += f'<rect x="{x+14}" y="{y+10}" width="{width}" height="{height}" rx="4" fill="{side}"/><rect x="{x}" y="{y}" width="{width}" height="{height}" rx="4" fill="{wall}"/><rect x="{x-8}" y="{y}" width="{width+16}" height="14" fill="{side}"/>'
        for row in range(3):
            for col in range(int(width/80)):
                wx, wy = x+22+col*80, y+42+row*72
                art += f'<rect x="{wx}" y="{wy}" width="53" height="44" rx="2" fill="{glass}"/><path d="M{wx+3} {wy+41}V{wy+3}H{wx+50}Z" fill="#d3eeea" opacity=".13"/><path d="M{wx+26} {wy}V{wy+44}M{wx} {wy+22}H{wx+53}" stroke="{side}" stroke-width="3"/><rect x="{wx-4}" y="{wy+44}" width="61" height="5" fill="{side}"/>'
        art += f'<rect x="{x+width/2-28}" y="530" width="56" height="75" rx="3" fill="{glass}"/><path d="M{x+width/2} 534V600" stroke="#dfdec5" stroke-width="3"/>'
        if j == 1:
            art += f'<rect x="{x+90}" y="{y+13}" width="320" height="23" rx="4" fill="#244d63"/><path d="M{x+width/2-42} 529L{x+width/2} 505L{x+width/2+42} 529Z" fill="{side}"/>'
    art += f'<path d="M0 606H1600V641H0Z" fill="{side}"/><path d="M0 610H1600" stroke="#f0dcaf" stroke-width="5"/>'
    # Original landscaping, rails, hedges and facade details.
    for x in range(40, 1600, 230):
        art += f'<path d="M{x} 605V493" stroke="#77908b" stroke-width="9"/><g fill="{far}"><circle cx="{x}" cy="484" r="34"/><circle cx="{x-22}" cy="510" r="29"/><circle cx="{x+22}" cy="511" r="31"/></g><circle cx="{x-8}" cy="478" r="24" fill="#b4d5b3" opacity=".24"/>'
    svg(f'campus{idx}.svg', art)

# Interior scenery has a distinct silhouette and architecture for each stage.
for level in [2, 3, 4]:
    wall = {2:'#d6c5ad',3:'#213c59',4:'#8d8297'}[level]
    trim = {2:'#a48b72',3:'#467086',4:'#c3a592'}[level]
    art = f'<rect y="110" width="1600" height="510" fill="{wall}"/><path d="M0 110H1600V135H0Z M0 585H1600V620H0Z" fill="{trim}"/>'
    for x in range(0,1600,400):
        art += f'<rect x="{x}" y="130" width="15" height="455" fill="{trim}"/>'
        if level == 2:
            art += f'<rect x="{x+42}" y="174" width="300" height="170" rx="5" fill="#375d68"/><rect x="{x+52}" y="184" width="280" height="150" fill="#427b78"/>'
            for n in range(3):
                art += f'<path d="M{x+77} {216+n*31}h{130-n*23}m20 0h45" stroke="#c8dcc3" stroke-width="3" opacity=".6"/>'
            art += f'<rect x="{x+38}" y="380" width="310" height="199" fill="#876f60"/>'
            for row in range(3):
                for b in range(13):
                    color=['#c4a170','#709c97','#bb7e77','#7b8ca8','#dcc69a'][b%5]
                    height=35+(b*17)%20
                    art+=f'<rect x="{x+48+b*22}" y="{438+row*61-height}" width="16" height="{height}" rx="1" fill="{color}"/><path d="M{x+51+b*22} {431+row*61}h10" stroke="#ead9b3" stroke-width="2" opacity=".7"/>'
                art+=f'<rect x="{x+38}" y="{439+row*61}" width="310" height="7" fill="#b39470"/>'
        elif level == 3:
            art+=f'<path d="M{x+35} 154H{x+360}V185H{x+280}" fill="none" stroke="#56828c" stroke-width="7"/><path d="M{x+75} 135V180H{x+115}V250" fill="none" stroke="#81ada8" stroke-width="3"/>'
            art+=f'<rect x="{x+31}" y="257" width="101" height="310" rx="8" fill="#172d47"/>'
            for y in range(278,550,42):
                art+=f'<rect x="{x+40}" y="{y}" width="82" height="29" rx="3" fill="#36516b"/><circle cx="{x+109}" cy="{y+14}" r="3" fill="#91e8c3"/>'
                for v in range(4): art+=f'<path d="M{x+47+v*11} {y+8}v13" stroke="#668b9a" stroke-width="3"/>'
            art+=f'<rect x="{x+160}" y="455" width="202" height="15" rx="3" fill="#88a2aa"/><path d="M{x+177} 470V580M{x+345} 470V580" stroke="#527789" stroke-width="9"/>'
            for monitor_x in [x+175,x+274]:
                art+=f'<rect x="{monitor_x}" y="365" width="80" height="65" rx="5" fill="#162e45"/><rect x="{monitor_x+6}" y="371" width="68" height="49" rx="3" fill="#438883"/><path d="M{monitor_x+40} 430V451M{monitor_x+22} 452H{monitor_x+58}" stroke="#6e8b9c" stroke-width="6"/>'
                art+=f'<path d="M{monitor_x+16} 382h19m8 0h15m-42 10h40m-40 10h25" stroke="#8be8c4" stroke-width="2"/>'
            art+=f'<path d="M{x+180} 225h140v80H{x+180}Z" fill="#2c4f69" stroke="#5c91a0" stroke-width="2"/><path d="M{x+200} 270h20v-20h30v35h30v-38h20" fill="none" stroke="#87d9c9" stroke-width="3"/>'
        else:
            art+=f'<path d="M{x+38} 165H{x+360}V564H{x+38}Z" fill="#465774"/><path d="M{x+38} 165H{x+128}Q{x+84} 350 {x+115} 564H{x+38}Z M{x+360} 165H{x+270}Q{x+310} 350 {x+282} 564H{x+360}Z" fill="#885a78"/>'
            for v in range(3):
                art+=f'<path d="M{x+50+v*20} 168V550 M{x+302+v*19} 168V550" stroke="#b67f91" stroke-width="5" opacity=".35"/>'
            art+=f'<circle cx="{x+200}" cy="290" r="55" fill="#d4bc8e"/><circle cx="{x+200}" cy="290" r="47" fill="#e9d3a5"/><path d="M{x+163} 280 {x+200} 260 {x+237} 280 {x+200} 300Z M{x+177} 299V316Q{x+200} 335 {x+223} 316V299L{x+200} 312Z" fill="#596a7b"/>'
            art+=f'<path d="M{x+140} 423H{x+263}L{x+249} 564H{x+155}Z" fill="#a98d7f"/><path d="M{x+133} 417H{x+270}V433H{x+133}Z" fill="#d7ba96"/>'
            art+=f'<path d="M{x+190} 414V393q0-20 16-20" fill="none" stroke="#34455e" stroke-width="4"/>'
    art+='<rect y="611" width="1600" height="45" fill="#4a6572"/><path d="M0 613H1600" stroke="#d4c8a6" stroke-width="4"/>'
    svg(f'campus{level}.svg', art)

# Fonts are resolved with Godot SystemFont; no proprietary font is redistributed.
for generated_font in [ART / 'Interface.ttf', ART / 'Interface.ttf.import']:
    if generated_font.exists():
        generated_font.unlink()

RATE = 22050
TAU = math.tau

def wav(name, samples):
    with wave.open(str(AUDIO / f'{name}.wav'), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h', int(max(-.98,min(.98,s))*32767)) for s in samples))

def music(name, bpm, root, mood):
    beat = 60/bpm
    duration = beat*32
    samples = [0.0]*int(duration*RATE)
    scale = [0, 2, 4 if mood != 'dark' else 3, 7, 9 if mood != 'dark' else 10, 12, 14, 16 if mood != 'dark' else 15]
    melody = [0,2,3,4, 3,2,1,3, 2,4,5,3, 4,3,1,2, 0,3,4,5, 7,5,4,3, 2,3,1,2, 3,1,0,0]
    def note(start, length, midi, gain, voice):
        freq = 440*2**((midi-69)/12)
        start_i = int(start*RATE)
        count = int(length*RATE)
        for n in range(count):
            i = start_i+n
            if i >= len(samples): break
            t = n/RATE
            env = min(1, t/.012)*min(1,(length-t)/.08)
            if voice == 'pluck':
                sig = (math.sin(TAU*freq*t)+.23*math.sin(TAU*freq*2*t)+.1*math.sin(TAU*freq*3*t))*math.exp(-t*5)
            else:
                sig = math.sin(TAU*freq*t)*.85 + math.sin(TAU*freq*2*t)*.15
            samples[i] += sig*env*gain
    chords = [0, -5, -3, -7]
    for bar in range(8):
        base = root+chords[bar%4]
        for degree in [0, 3 if mood == 'dark' else 4, 7]:
            note(bar*beat*4, beat*3.95, base+degree, .038, 'pad')
        for b in range(4):
            note((bar*4+b)*beat, beat*.75, base-12+(7 if b%2 else 0), .12, 'bass')
            tone = root+12+scale[melody[bar*4+b]]
            note((bar*4+b)*beat, beat*.8, tone, .15, 'pluck')
            if b%2 == 0:
                note((bar*4+b+.5)*beat, beat*.36, tone+7, .045, 'pluck')
    rng = random.Random(9)
    for eighth in range(64):
        start = int(eighth*beat*.5*RATE)
        for n in range(int(.065*RATE)):
            if start+n < len(samples):
                t=n/RATE
                samples[start+n] += rng.uniform(-1,1)*math.exp(-t*65)*(.035 if eighth%2 else .025)
        if eighth%2==0:
            for n in range(int(.16*RATE)):
                if start+n<len(samples):
                    t=n/RATE
                    samples[start+n] += math.sin(TAU*(62*t+1.8*(1-math.exp(-t*25))))*math.exp(-t*27)*.12
    wav(name,samples)

for spec in [('menu',96,57,'warm'),('level1',112,60,'warm'),('level2',120,62,'warm'),('level3',128,57,'dark'),('level4',116,65,'warm'),('chase',150,62,'dark'),('boss',140,54,'dark'),('graduation',90,60,'warm')]:
    music(*spec)

effects = {'jump':(.18,360,850), 'coin':(.16,1050,1600), 'hit':(.14,180,60), 'hurt':(.32,260,70), 'alert':(.28,540,900), 'attack':(.14,320,100), 'step':(.045,100,65), 'land':(.10,130,55), 'slide':(.25,180,60), 'checkpoint':(.6,550,1100), 'door':(.4,170,320), 'eagle':(.7,700,1400), 'power':(.55,420,1250), 'shield':(.35,840,280), 'victory':(1.3,520,1040)}
for name,(duration,a,b) in effects.items():
    rng=random.Random(17)
    samples=[]
    for i in range(int(RATE*duration)):
        t=i/RATE
        env=min(1,t/.006)*(1-t/duration)**1.7
        phase=TAU*(a*t+(b-a)*t*t/(2*duration))
        tone=math.sin(phase)+.2*math.sin(2*phase)
        if name in ['hit','hurt','step','land','slide','attack']: tone=.45*tone+.55*rng.uniform(-1,1)
        if name in ['victory','checkpoint','power']:
            freq=a*([1,1.25,1.5,2][min(3,int(t/duration*4))])
            tone=math.sin(TAU*freq*t)*.8+math.sin(TAU*freq*2*t)*.2
        samples.append(tone*env*.35)
    wav(name,samples)
print(f'Generated {len(list(ART.iterdir()))} art files, {len(list(AUDIO.glob("*.wav")))} audio files.')
