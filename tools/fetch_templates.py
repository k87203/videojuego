"""Download only the Windows templates from the official Godot archive with HTTP ranges."""
import argparse
import io
import json
import urllib.request
import zipfile
from pathlib import Path

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
parser = argparse.ArgumentParser()
parser.add_argument('--output', default=str(Path(__file__).resolve().parents[1]/'.godot'/'windows-template'))
args = parser.parse_args()
dest = Path(args.output).resolve()
dest.mkdir(parents=True, exist_ok=True)

class RemoteZip(io.RawIOBase):
    def __init__(self):
        self.pos = 0
        head = urllib.request.Request(URL, method='HEAD', headers={'User-Agent':'TecnoAventura-build/0.2'})
        with urllib.request.urlopen(head, timeout=60) as response:
            self.url = response.geturl()
            self.length = int(response.headers['Content-Length'])
        request = urllib.request.Request(self.url, headers={'Range':f'bytes={self.length-65557}-{self.length-1}', 'User-Agent':'TecnoAventura-build/0.2'})
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206: raise RuntimeError('Server did not honor HTTP range request')
            self.tail = response.read()
        self.tail_start = self.length-len(self.tail)
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence==0 else (self.pos+offset if whence==1 else self.length+offset)
        return self.pos
    def read(self, size=-1):
        if size<0: size=self.length-self.pos
        if size==0: return b''
        start,end=self.pos,min(self.length,self.pos+size)
        if start>=self.tail_start:
            data=self.tail[start-self.tail_start:end-self.tail_start]
        else:
            request=urllib.request.Request(self.url, headers={'Range':f'bytes={start}-{end-1}', 'User-Agent':'TecnoAventura-build/0.2'})
            with urllib.request.urlopen(request, timeout=90) as response:
                if response.status!=206: raise RuntimeError('Server did not honor HTTP range request')
                data=response.read(end-start+1)
                if len(data)!=end-start: raise RuntimeError('Unexpected response size')
        self.pos+=len(data)
        return data

with zipfile.ZipFile(RemoteZip()) as archive:
    selected=[i for i in archive.infolist() if Path(i.filename).name in ['windows_release_x86_64.exe','windows_debug_x86_64.exe','version.txt']]
    if len(selected)!=3: raise RuntimeError('Official Windows templates were not found')
    for entry in selected:
        target=dest/Path(entry.filename).name
        if target.exists() and target.stat().st_size==entry.file_size: continue
        print(f'Downloading {target.name}: {entry.compress_size/1048576:.1f} MiB',flush=True)
        target.write_bytes(archive.read(entry))
        print('CRC verified: '+target.name,flush=True)
if (dest/'version.txt').read_text().strip()!='4.7.2.stable': raise RuntimeError('Template version mismatch')
(dest/'source.json').write_text(json.dumps({'url':URL,'version':'4.7.2.stable','verification':'Official HTTPS ZIP entries; decompression and CRC validated'},indent=2))
