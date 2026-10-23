"""Original 48-bar electronic/cartoon score. Keeps the previous WAV files intact.
NumPy performs offline synthesis; no sampled recordings or external melodies are used.
"""
from pathlib import Path
import json
import math
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'audio'
SR=22050
TAU=math.tau
analysis=[]

def save(name, audio, bpm=0):
    peak=float(np.max(np.abs(audio)))
    if peak>0: audio=audio*(0.90/max(0.90,peak))
    pcm=(np.clip(audio,-.98,.98)*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(2 if audio.ndim==2 else 1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    analysis.append({'name':name,'seconds':len(audio)/SR,'bpm':bpm,'peak':float(np.max(np.abs(audio))),'rms':float(np.sqrt(np.mean(audio**2)))})
    print(f'Composed {name}: {len(audio)/SR:.1f}s',flush=True)

def compose(name,bpm,root,theme,intense=False):
    beat=60/bpm
    bars=48
    n=int(round(bars*4*beat*SR))
    mix=np.zeros((n,2),dtype=np.float32)
    rng=np.random.default_rng(400+theme)
    minor=theme in [3,5,6]
    scale=np.array([0,2,3,5,7,8,10] if minor else [0,2,4,5,7,9,11])
    progressions=[[0,5,3,4,0,2,5,4],[0,3,5,4,2,5,3,4],[0,5,2,4,3,5,4,4],[0,5,6,4,0,3,5,4]]
    progression=progressions[(theme-1)%4]
    motifs=[
        [[0,2,4,6,4,2,1,4],[4,5,6,8,7,4,2,1],[2,4,5,4,2,1,0,2]],
        [[4,2,5,4,6,5,2,4],[0,1,3,5,4,3,1,2],[6,4,2,1,0,2,4,6]],
        [[0,4,1,5,2,6,4,1],[5,4,2,1,0,4,6,5],[2,3,5,6,4,2,1,0]],
        [[0,2,4,7,6,4,5,6],[5,6,8,7,4,5,2,4],[3,2,1,4,6,5,4,0]]
    ][(theme-1)%4]
    def note(start,duration,midi,gain,voice='pluck',pan=0.0):
        count=max(1,int(duration*SR))
        t=np.arange(count,dtype=np.float32)/SR
        f=440*2**((midi-69)/12)
        env=np.minimum(1,t/.012)*np.minimum(1,np.maximum(0,duration-t)/.09)
        if voice=='pad':
            env*=np.minimum(1,t/.18)
            signal=(np.sin(TAU*f*t)+.35*np.sin(TAU*f*1.003*t)+.15*np.sin(TAU*f*2*t))*.6
        elif voice=='bass':
            signal=(np.sin(TAU*f*t)+.25*np.sin(TAU*f*2*t))*np.exp(-t*2)
        elif voice=='lead':
            signal=np.sin(TAU*f*t+1.1*np.sin(TAU*f*2*t)*np.exp(-t*5))*.8+.15*np.sin(TAU*f*3*t)
        elif voice=='bell':
            signal=(np.sin(TAU*f*t)+.35*np.sin(TAU*f*2.7*t)*np.exp(-t*7))*np.exp(-t*3.5)
        else:
            signal=(np.sin(TAU*f*t)+.25*np.sin(TAU*f*2*t)+.12*np.sin(TAU*f*3*t))*np.exp(-t*4)
        signal*=env*gain
        at=int(round(start*SR))%n
        stereo=np.stack([signal*math.sqrt((1-pan)/2),signal*math.sqrt((1+pan)/2)],axis=1)
        end=min(n,at+count)
        mix[at:end]+=stereo[:end-at]
        if at+count>n: mix[:at+count-n]+=stereo[end-at:]
    def drum(start,kind,gain):
        duration={'kick':.22,'snare':.16,'hat':.055,'crash':.65}[kind]
        t=np.arange(int(SR*duration),dtype=np.float32)/SR
        noise=rng.uniform(-1,1,len(t)).astype(np.float32)
        if kind=='kick': signal=np.sin(TAU*(47*t+2.7*(1-np.exp(-t*28))))*np.exp(-t*19)
        elif kind=='snare': signal=(noise*.8+np.sin(TAU*180*t)*.2)*np.exp(-t*27)
        elif kind=='hat': signal=(noise-np.roll(noise,1))*np.exp(-t*75)*.5
        else: signal=noise*np.exp(-t*7)*.6
        at=int(round(start*SR))%n
        end=min(n,at+len(t))
        mix[at:end]+=(signal[:end-at]*gain)[:,None]
    for bar in range(bars):
        phrase=bar//8
        degree=progression[bar%8]
        base=root+int(scale[degree%7])
        chord_minor=minor if degree in [0,3,4] else degree in [1,2,5]
        for third in [0,3 if chord_minor else 4,7]:
            note(bar*4*beat,beat*3.85,base+third,.042 if intense else .03,'pad',-.35 if third==0 else .35)
        for b in range(4):
            if intense or b%2==0:
                note((bar*4+b)*beat,beat*.72,base-12+(7 if b==2 else 0),.19 if intense else .14,'bass')
            if b in [0,2] or intense:
                drum((bar*4+b)*beat,'kick',.22 if intense else .16)
            if b in [1,3]: drum((bar*4+b)*beat,'snare',.10 if intense else .06)
            drum((bar*4+b+.5)*beat,'hat',.065 if intense else .03)
            if intense: drum((bar*4+b+.25)*beat,'hat',.022)
        if bar%8==0: drum(bar*4*beat,'crash',.07 if intense else .035)
        motif=motifs[(phrase+(bar//4))%3]
        for b in range(4):
            step=motif[(bar%2)*4+b]
            if phrase in [2,4]: step=(step+2)%10
            midi=root+12+int(scale[step%7])+12*(step//7)
            if phrase==3 and b==1: continue
            voice='lead' if theme in [3,5,6] or intense else ('bell' if theme==2 else 'pluck')
            note((bar*4+b)*beat,beat*(.70 if b!=3 else .94),midi,.145 if intense else .115,voice,.13*math.sin(bar+b))
            if (bar+b)%3==0 or (intense and b%2==0):
                note((bar*4+b+.5)*beat,beat*.35,midi+7,.055,'bell',.45)
        if bar%4==3:
            for fill in range(4 if intense else 2): drum((bar*4+3+fill/(4 if intense else 2))*beat,'snare',.04+fill*.008)
    # Stereo delays wrap into the beginning, so the loop has a continuous ambience.
    dry=mix.copy()
    for delay,gain in [(beat*.75,.17),(.089,.06),(.173,.045),(.293,.03)]:
        echo=np.roll(dry,int(delay*SR),axis=0)
        mix+=echo[:,::-1]*gain
    mix=np.tanh(mix*1.3)
    save(name,mix,bpm)

for level,bpm,root in [(1,116,60),(2,124,62),(3,132,57),(4,120,65)]:
    compose(f'campus_{level}',bpm,root,level)
    compose(f'campus_{level}_intense',bpm,root,level,True)
compose('modern_menu',104,60,1)
compose('urgent_chase',156,57,5,True)
compose('epic_boss',138,54,6,True)
compose('epic_final',152,54,6,True)
compose('ceremony',96,60,4)
for index,name in enumerate(['ability_alex','ability_valeria','ability_diego','ability_sofia','crumble','trial']):
    duration=.45 if index!=4 else .7
    t=np.arange(int(SR*duration),dtype=np.float32)/SR
    if name=='crumble':
        signal=np.random.default_rng(45).uniform(-1,1,len(t))*np.exp(-t*9)*.3
    else:
        freq=330+index*110
        signal=np.sin(TAU*(freq*t+freq*t*t))*np.minimum(1,t/.008)*(1-t/duration)**2*.35
        signal+=np.sin(TAU*freq*1.5*t)*np.exp(-t*8)*.12
    save(name,signal.astype(np.float32))
(ROOT/'docs'/'music-analysis.json').write_text(json.dumps({'method':'Original offline synthesis. 48-bar forms with six phrases, harmony, bass, percussion and stereo delay. No third-party recordings.','tracks':analysis},indent=2),encoding='utf-8')
